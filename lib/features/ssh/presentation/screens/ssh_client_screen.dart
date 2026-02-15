import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/services/ssh_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../shared/models/connection_profile.dart';
import '../../../connections/presentation/providers/connections_provider.dart';

class SSHClientScreen extends ConsumerStatefulWidget {
  final ConnectionProfile? initialConnection;
  final bool autoConnect;

  const SSHClientScreen({
    super.key,
    this.initialConnection,
    this.autoConnect = false,
  });

  @override
  ConsumerState<SSHClientScreen> createState() => _SSHClientScreenState();
}

class _SSHClientScreenState extends ConsumerState<SSHClientScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final Terminal _terminal = Terminal(maxLines: 10000);
  final TerminalController _terminalController = TerminalController();
  final FocusNode _terminalFocusNode = FocusNode();

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _showPassword = false;

  StreamSubscription<Uint8List>? _shellStdoutSub;
  StreamSubscription<Uint8List>? _shellStderrSub;

  bool get _isDesktopPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  final List<Map<String, String>> _snippets = [
    {'name': 'System Info', 'cmd': 'uname -a'},
    {'name': 'Disk Usage', 'cmd': 'df -h'},
    {'name': 'Memory', 'cmd': 'free -m'},
    {'name': 'CPU Info', 'cmd': 'top -bn1 | head -5'},
    {'name': 'Processes', 'cmd': 'ps aux --sort=-%mem | head -15'},
    {'name': 'Network', 'cmd': 'ifconfig || ip addr'},
    {'name': 'Uptime', 'cmd': 'uptime'},
    {'name': 'Users', 'cmd': 'who'},
    {'name': 'Services', 'cmd': 'systemctl list-units --state=running'},
    {'name': 'Logs', 'cmd': 'journalctl -n 20 --no-pager'},
  ];

  @override
  void initState() {
    super.initState();

    _terminal.onOutput = (data) {
      _sendToShell(data);
    };

    _prefillFromConnection();
  }

  Future<void> _prefillFromConnection() async {
    final conn = widget.initialConnection;
    if (conn == null) return;

    _hostController.text = conn.host;
    _portController.text = conn.port.toString();
    _usernameController.text = conn.username;

    final creds = await ref
        .read(secureStorageServiceProvider)
        .getConnectionCredentials(conn.id);
    if (creds != null && creds['password'] != null) {
      _passwordController.text = creds['password']!;
    }

    if (widget.autoConnect && mounted) {
      if (_passwordController.text.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isConnecting || _isConnected) return;
        _connect();
      });
    }
  }

  @override
  void dispose() {
    _shellStdoutSub?.cancel();
    _shellStderrSub?.cancel();
    ref.read(sshServiceProvider).disconnect();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _terminalController.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final port = int.tryParse(_portController.text.trim()) ?? 22;

    if (host.isEmpty || username.isEmpty) {
      _showSnack('Please fill in host and username');
      return;
    }
    if (password.isEmpty) {
      _showSnack('Password is required');
      return;
    }

    setState(() => _isConnecting = true);
    _terminal.write('Connecting to $username@$host:$port ...\r\n');

    try {
      final sshService = ref.read(sshServiceProvider);
      await sshService.connectWithPassword(
        host: host,
        port: port,
        username: username,
        password: password,
      );

      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _isConnected = true;
      });

      final conn = widget.initialConnection;
      if (conn != null) {
        await ref.read(connectionsProvider.notifier).updateLastConnected(conn.id);
        if (password.isNotEmpty) {
          await ref
              .read(secureStorageServiceProvider)
              .saveConnectionCredentials(conn.id, {'password': password});
        }
      }

      await _startInteractiveShell();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConnecting = false);
      _terminal.write('\x1B[31mConnection failed: ${_formatError(e)}\x1B[0m\r\n');
    }
  }

  Future<void> _startInteractiveShell() async {
    try {
      final sshService = ref.read(sshServiceProvider);
      final shell = await sshService.startShell(
        pty: SSHPtyConfig(
          type: 'xterm-256color',
          width: _terminal.viewWidth,
          height: _terminal.viewHeight,
        ),
      );

      _shellStdoutSub = shell.stdout.listen((data) {
        if (!mounted) return;
        _terminal.write(utf8.decode(data, allowMalformed: true));
      });

      _shellStderrSub = shell.stderr.listen((data) {
        if (!mounted) return;
        _terminal.write(utf8.decode(data, allowMalformed: true));
      });

      shell.done.then((_) {
        if (!mounted) return;
        _handleDisconnect('Shell session ended');
      });

      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        try {
          sshService.resizeShell(width, height);
        } catch (_) {}
      };

      _focusTerminalInput();
    } catch (e) {
      if (!mounted) return;
      _terminal.write('\x1B[31mFailed to start shell: ${_formatError(e)}\x1B[0m\r\n');
    }
  }

  void _focusTerminalInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isConnected) return;
      FocusScope.of(context).unfocus();
      FocusScope.of(context).requestFocus(_terminalFocusNode);
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  void _sendToShell(String data) {
    if (!_isConnected) return;
    final sshService = ref.read(sshServiceProvider);
    if (sshService.currentSession?.shell == null) return;
    try {
      sshService.writeToShell(data);
    } catch (_) {}
  }

  Future<void> _disconnect() async {
    _shellStdoutSub?.cancel();
    _shellStderrSub?.cancel();
    _shellStdoutSub = null;
    _shellStderrSub = null;
    await ref.read(sshServiceProvider).disconnect();
    _handleDisconnect('Disconnected');
  }

  void _handleDisconnect(String reason) {
    if (!mounted) return;
    setState(() {
      _isConnected = false;
      _isConnecting = false;
    });
    _terminal.write('\r\n\x1B[33m[$reason]\x1B[0m\r\n');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatError(dynamic error) {
    final msg = error.toString();
    if (msg.contains('SocketException')) {
      if (msg.contains('Connection refused')) return 'Connection refused';
      if (msg.contains('timed out')) return 'Connection timed out';
      if (msg.contains('No route to host')) return 'No route to host';
      if (msg.contains('Network is unreachable')) return 'Network unreachable';
    }
    if (msg.contains('SSHAuthFailError') || msg.contains('auth')) {
      return 'Authentication failed';
    }
    if (msg.contains('HandshakeException') || msg.contains('handshake')) {
      return 'SSH handshake failed';
    }
    if (msg.length > 120) return msg.substring(0, 120);
    return msg;
  }

  void _sendQuickCommand(String command) {
    if (!_isConnected) return;
    _sendToShell('$command\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.terminal, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('SSH Client'),
          ],
        ),
        actions: [
          if (_isConnected)
            TextButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.close, size: 18, color: AppTheme.error),
              label: const Text('Disconnect',
                  style: TextStyle(color: AppTheme.error)),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'snippets':
                  _showSnippets();
                  return;
                case 'clear':
                  _terminal.buffer.clear();
                  _terminal.buffer.setCursor(0, 0);
                  return;
                case 'ctrlc':
                  _sendToShell('\x03');
                  return;
                case 'ctrld':
                  _sendToShell('\x04');
                  return;
                case 'ctrll':
                  _sendToShell('\x0c');
                  return;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'snippets', child: Text('Quick Commands')),
              const PopupMenuItem(value: 'clear', child: Text('Clear Terminal')),
              if (_isConnected) ...[
                const PopupMenuItem(value: 'ctrlc', child: Text('Send Ctrl+C')),
                const PopupMenuItem(value: 'ctrld', child: Text('Send Ctrl+D')),
                const PopupMenuItem(value: 'ctrll', child: Text('Send Ctrl+L')),
              ],
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState:
                _isConnected ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: _buildConnectionForm(),
            secondChild: const SizedBox.shrink(),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              decoration: BoxDecoration(
                color: AppTheme.terminalBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: [
                    _buildTerminalHeader(),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _focusTerminalInput,
                        child: TerminalView(
                          _terminal,
                          key: ValueKey(_isConnected),
                          controller: _terminalController,
                          focusNode: _terminalFocusNode,
                          autofocus: true,
                          hardwareKeyboardOnly: _isDesktopPlatform,
                          onTapUp: (details, cellOffset) => _focusTerminalInput(),
                          backgroundOpacity: 0.0,
                          padding: const EdgeInsets.all(8),
                          textStyle: TerminalStyle(
                            fontSize: 14,
                            fontFamily: GoogleFonts.firaCode().fontFamily!,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Special Keys Toolbar
          if (_isConnected) _buildSpecialKeysToolbar(),
        ],
      ),
    );
  }

  Widget _buildSpecialKeysToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(top: BorderSide(color: AppTheme.darkBorder, width: 1)),
      ),
      child: Row(
        children: [
          _ToolbarKey(label: 'ESC', onTap: () => _sendToShell('\x1B')),
          _ToolbarKey(label: 'TAB', onTap: () => _sendToShell('\t')),
          _ToolbarKey(label: 'CTRL', onTap: _showCtrlMenu, hasDropdown: true),
          _ToolbarKey(label: 'ALT', onTap: _showAltMenu, hasDropdown: true),
          const SizedBox(width: 8),
          // Arrow keys
          _ToolbarKey(icon: Icons.keyboard_arrow_up, onTap: () => _sendToShell('\x1B[A')),
          _ToolbarKey(icon: Icons.keyboard_arrow_down, onTap: () => _sendToShell('\x1B[B')),
          _ToolbarKey(icon: Icons.keyboard_arrow_left, onTap: () => _sendToShell('\x1B[D')),
          _ToolbarKey(icon: Icons.keyboard_arrow_right, onTap: () => _sendToShell('\x1B[C')),
          const Spacer(),
          _ToolbarKey(icon: Icons.keyboard, onTap: _focusTerminalInput),
        ],
      ),
    );
  }

  void _showCtrlMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CtrlKeyButton('C', () { Navigator.pop(context); _sendToShell('\x03'); }),
            _CtrlKeyButton('D', () { Navigator.pop(context); _sendToShell('\x04'); }),
            _CtrlKeyButton('Z', () { Navigator.pop(context); _sendToShell('\x1A'); }),
            _CtrlKeyButton('L', () { Navigator.pop(context); _sendToShell('\x0C'); }),
            _CtrlKeyButton('A', () { Navigator.pop(context); _sendToShell('\x01'); }),
            _CtrlKeyButton('E', () { Navigator.pop(context); _sendToShell('\x05'); }),
            _CtrlKeyButton('K', () { Navigator.pop(context); _sendToShell('\x0B'); }),
            _CtrlKeyButton('U', () { Navigator.pop(context); _sendToShell('\x15'); }),
            _CtrlKeyButton('W', () { Navigator.pop(context); _sendToShell('\x17'); }),
            _CtrlKeyButton('R', () { Navigator.pop(context); _sendToShell('\x12'); }),
          ],
        ),
      ),
    );
  }

  void _showAltMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CtrlKeyButton('B', () { Navigator.pop(context); _sendToShell('\x1Bb'); }),
            _CtrlKeyButton('F', () { Navigator.pop(context); _sendToShell('\x1Bf'); }),
            _CtrlKeyButton('D', () { Navigator.pop(context); _sendToShell('\x1Bd'); }),
            _CtrlKeyButton('.', () { Navigator.pop(context); _sendToShell('\x1B.'); }),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withAlpha(10)),
      child: Row(
        children: [
          _dot(_isConnected
              ? AppTheme.success
              : (_isConnecting ? AppTheme.warning : Colors.grey)),
          const SizedBox(width: 6),
          _dot(AppTheme.warning),
          const SizedBox(width: 6),
          _dot(AppTheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isConnected
                  ? '${_usernameController.text}@${_hostController.text} (shell)'
                  : 'Terminal',
              style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white54),
            ),
          ),
          if (_isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.success.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'LIVE',
                style: GoogleFonts.firaCode(
                  fontSize: 10,
                  color: AppTheme.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _buildConnectionForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host',
                    hintText: '192.168.1.1',
                    prefixIcon: Icon(Icons.dns),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isConnecting ? null : _connect,
            icon: _isConnecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.login),
            label: Text(_isConnecting ? 'Connecting...' : 'Connect via SSH'),
          ),
        ],
      ),
    );
  }

  void _showSnippets() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Commands',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _snippets
                  .map((s) => ActionChip(
                        label: Text(s['name']!),
                        avatar: const Icon(Icons.play_arrow, size: 16),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _sendQuickCommand(s['cmd']!);
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ToolbarKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool hasDropdown;

  const _ToolbarKey({
    this.label,
    this.icon,
    required this.onTap,
    this.hasDropdown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: AppTheme.darkElevated,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: label != null ? 12 : 8,
              vertical: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon, size: 18, color: Colors.white70),
                if (label != null)
                  Text(
                    label!,
                    style: GoogleFonts.firaCode(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                if (hasDropdown)
                  const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Icon(Icons.arrow_drop_down, size: 14, color: Colors.white54),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CtrlKeyButton extends StatelessWidget {
  final String keyChar;
  final VoidCallback onTap;

  const _CtrlKeyButton(this.keyChar, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.darkElevated,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'CTRL+$keyChar',
            style: GoogleFonts.firaCode(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.cyan,
            ),
          ),
        ),
      ),
    );
  }
}
