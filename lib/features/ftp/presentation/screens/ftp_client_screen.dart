import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../shared/models/connection_profile.dart';

class FTPClientScreen extends ConsumerStatefulWidget {
  final ConnectionProfile? initialConnection;
  final bool autoConnect;

  const FTPClientScreen({
    super.key,
    this.initialConnection,
    this.autoConnect = false,
  });

  @override
  ConsumerState<FTPClientScreen> createState() => _FTPClientScreenState();
}

class _FTPClientScreenState extends ConsumerState<FTPClientScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '21');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _showPassword = false;
  String _currentPath = '/';
  String _protocol = 'FTP';
  String? _serverBanner;
  String? _connectionError;

  final List<_RemoteFile> _files = [];

  @override
  void initState() {
    super.initState();
    _prefillFromConnection();
  }

  Future<void> _prefillFromConnection() async {
    final conn = widget.initialConnection;
    if (conn == null) return;

    _hostController.text = conn.host;
    _portController.text = conn.port.toString();
    _usernameController.text = conn.username;
    _protocol = conn.type == ConnectionType.sftp ? 'SFTP' : 'FTP';

    final creds = await ref
        .read(secureStorageServiceProvider)
        .getConnectionCredentials(conn.id);
    final password = creds?['password'];
    if (password != null && password.isNotEmpty) {
      _passwordController.text = password;
    }

    if (widget.autoConnect && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isConnecting || _isConnected) return;
        _connect();
      });
    }
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;
    final port = int.tryParse(_portController.text.trim()) ?? (_protocol == 'SFTP' ? 22 : 21);
    if (port < 1 || port > 65535) {
      setState(() => _connectionError = 'Invalid port number');
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectionError = null;
      _serverBanner = null;
      _files.clear();
    });

    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
      final banner = await _readBanner(socket);

      if (_protocol == 'SFTP' && banner != null && !banner.startsWith('SSH-')) {
        throw Exception('Target does not appear to be an SSH/SFTP server');
      }
      if ((_protocol == 'FTP' || _protocol == 'FTPS') &&
          banner != null &&
          banner.isNotEmpty &&
          !banner.startsWith('220')) {
        throw Exception('Target does not appear to be an FTP server');
      }

      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _isConnected = true;
        _currentPath = '/';
        _serverBanner = banner;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _isConnected = false;
        _connectionError = _formatConnectError(e);
      });
    } finally {
      socket?.destroy();
    }
  }

  void _disconnect() {
    setState(() {
      _isConnected = false;
      _files.clear();
      _serverBanner = null;
    });
  }

  Future<String?> _readBanner(Socket socket) async {
    final completer = Completer<String?>();
    late StreamSubscription<Uint8List> sub;

    sub = socket.listen(
      (data) {
        if (completer.isCompleted) return;
        final line = utf8.decode(data, allowMalformed: true).trim();
        completer.complete(line.isEmpty ? null : line);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(null);
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
      cancelOnError: true,
    );

    final banner = await completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
    await sub.cancel();
    return banner;
  }

  String _formatConnectError(Object e) {
    final msg = e.toString();
    final lower = msg.toLowerCase();
    if (lower.contains('refused')) return 'Connection refused by server';
    if (lower.contains('timed out')) return 'Connection timed out';
    if (lower.contains('no route to host') || lower.contains('unreachable')) {
      return 'Host unreachable';
    }
    return msg;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'sql': return Icons.storage;
      case 'yml':
      case 'yaml':
      case 'json':
      case 'xml': return Icons.data_object;
      case 'log': return Icons.article;
      case 'md': return Icons.description;
      case 'env': return Icons.vpn_key;
      case 'sh': return Icons.terminal;
      case 'py': return Icons.code;
      case 'js':
      case 'ts': return Icons.javascript;
      case 'html':
      case 'css': return Icons.web;
      case 'zip':
      case 'tar':
      case 'gz': return Icons.archive;
      case 'jpg':
      case 'png':
      case 'gif': return Icons.image;
      default: return Icons.insert_drive_file;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.folder_shared, size: 22),
            const SizedBox(width: 8),
            Text('$_protocol Client'),
          ],
        ),
        actions: [
          if (_isConnected)
            TextButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.close, size: 18, color: AppTheme.error),
              label: const Text('Disconnect', style: TextStyle(color: AppTheme.error)),
            ),
        ],
      ),
      body: _isConnected ? _buildFileManager(theme) : _buildConnectionForm(theme),
    );
  }

  Widget _buildConnectionForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Protocol selector
          Text('Protocol', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'FTP', label: Text('FTP')),
              ButtonSegment(value: 'FTPS', label: Text('FTPS')),
              ButtonSegment(value: 'SFTP', label: Text('SFTP')),
            ],
            selected: {_protocol},
            onSelectionChanged: (v) {
              setState(() {
                _protocol = v.first;
                if (_protocol == 'SFTP') {
                  _portController.text = '22';
                } else {
                  _portController.text = '21';
                }
              });
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host',
                    hintText: 'ftp.example.com',
                    prefixIcon: Icon(Icons.dns),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _portController,
                  decoration: const InputDecoration(labelText: 'Port'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_connectionError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: AppTheme.error.withAlpha(20),
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: AppTheme.error),
                  title: Text(_connectionError!),
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: _isConnecting ? null : _connect,
            icon: _isConnecting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.login),
            label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }

  Widget _buildFileManager(ThemeData theme) {
    return Column(
      children: [
        // Path bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.cardTheme.color,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Navigate up')),
                  );
                },
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _currentPath,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.create_new_folder, size: 20),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.upload_file, size: 20),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File picker would open here')),
                  );
                },
              ),
            ],
          ),
        ),

        // File list
        Expanded(
          child: _files.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_done, size: 42, color: AppTheme.success),
                        const SizedBox(height: 10),
                        Text(
                          'Connected to ${_hostController.text}',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        if (_serverBanner != null && _serverBanner!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _serverBanner!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(140),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Realtime handshake complete. Directory browsing will use protocol APIs next.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(120),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (file.isDirectory ? AppTheme.accent : AppTheme.info).withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          file.isDirectory ? Icons.folder : _fileIcon(file.name),
                          color: file.isDirectory ? AppTheme.accent : AppTheme.info,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        file.name,
                        style: TextStyle(
                          fontWeight: file.isDirectory ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        file.isDirectory
                            ? 'Directory'
                            : '${_formatSize(file.size)} • ${_formatDate(file.modified)}',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(100)),
                      ),
                    );
                  },
                ),
          ),

        // Status bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.cardTheme.color,
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 14, color: AppTheme.success),
              const SizedBox(width: 6),
              Text(
                'Connected to ${_hostController.text}',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(120)),
              ),
              const Spacer(),
              Text(
                '${_files.where((f) => !f.isDirectory).length} files, ${_files.where((f) => f.isDirectory).length} folders',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(120)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class _RemoteFile {
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime modified;

  _RemoteFile({
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modified,
  });
}
