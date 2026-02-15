import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../shared/models/connection_profile.dart';
import '../providers/connections_provider.dart';

class AddConnectionScreen extends ConsumerStatefulWidget {
  final ConnectionProfile? editConnection;

  const AddConnectionScreen({super.key, this.editConnection});

  @override
  ConsumerState<AddConnectionScreen> createState() => _AddConnectionScreenState();
}

class _AddConnectionScreenState extends ConsumerState<AddConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _notesController = TextEditingController();
  final _groupController = TextEditingController();

  ConnectionType _type = ConnectionType.ssh;
  AuthType _authType = AuthType.password;
  bool _showPassword = false;

  bool get _isEditing => widget.editConnection != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.editConnection!;
      _nameController.text = c.name;
      _hostController.text = c.host;
      _portController.text = c.port.toString();
      _usernameController.text = c.username;
      _notesController.text = c.notes ?? '';
      _groupController.text = c.group ?? '';
      _type = c.type;
      _authType = c.authType;
    } else {
      _portController.text = '22';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  int _defaultPort() {
    switch (_type) {
      case ConnectionType.ssh:
      case ConnectionType.sftp:
        return 22;
      case ConnectionType.ftp:
        return 21;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final connection = ConnectionProfile(
      id: _isEditing ? widget.editConnection!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text) ?? _defaultPort(),
      username: _usernameController.text.trim(),
      type: _type,
      authType: _authType,
      group: _groupController.text.trim().isEmpty ? null : _groupController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: _isEditing ? widget.editConnection!.createdAt : DateTime.now(),
    );

    if (_isEditing) {
      await ref.read(connectionsProvider.notifier).updateConnection(connection);
    } else {
      await ref.read(connectionsProvider.notifier).addConnection(connection);
    }

    if (_authType == AuthType.password && _passwordController.text.isNotEmpty) {
      await ref.read(secureStorageServiceProvider).saveConnectionCredentials(
        connection.id,
        {
          'password': _passwordController.text,
        },
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditing ? 'Connection updated' : 'Connection saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Connection' : 'New Connection'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Connection Type
            Text('Connection Type', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ConnectionType>(
              segments: const [
                ButtonSegment(value: ConnectionType.ssh, label: Text('SSH'), icon: Icon(Icons.terminal)),
                ButtonSegment(value: ConnectionType.ftp, label: Text('FTP'), icon: Icon(Icons.folder_open)),
                ButtonSegment(value: ConnectionType.sftp, label: Text('SFTP'), icon: Icon(Icons.folder_special)),
              ],
              selected: {_type},
              onSelectionChanged: (value) {
                setState(() {
                  _type = value.first;
                  if (_portController.text == '22' || _portController.text == '21') {
                    _portController.text = _defaultPort().toString();
                  }
                });
              },
            ),

            const SizedBox(height: 24),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Connection Name',
                hintText: 'e.g., Production Server',
                prefixIcon: Icon(Icons.label),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),

            const SizedBox(height: 16),

            // Host & Port row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Host / IP',
                      hintText: '192.168.1.1 or server.com',
                      prefixIcon: Icon(Icons.dns),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final port = int.tryParse(v);
                      if (port == null || port < 1 || port > 65535) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Username
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'root',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),

            const SizedBox(height: 16),

            // Auth Type
            Text('Authentication', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<AuthType>(
              segments: const [
                ButtonSegment(value: AuthType.password, label: Text('Password'), icon: Icon(Icons.key)),
                ButtonSegment(value: AuthType.key, label: Text('SSH Key'), icon: Icon(Icons.vpn_key)),
              ],
              selected: {_authType},
              onSelectionChanged: (value) {
                setState(() => _authType = value.first);
              },
            ),

            const SizedBox(height: 16),

            if (_authType == AuthType.password) ...[
              TextFormField(
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
            ] else ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Select SSH Key File'),
                  subtitle: const Text('Tap to choose a private key'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File picker would open here')),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Optional fields
            ExpansionTile(
              title: const Text('Advanced Settings'),
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _groupController,
                  decoration: const InputDecoration(
                    labelText: 'Group (optional)',
                    hintText: 'e.g., Production, Staging',
                    prefixIcon: Icon(Icons.folder),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Any additional notes...',
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
              ],
            ),

            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _save,
              icon: Icon(_isEditing ? Icons.save : Icons.add),
              label: Text(_isEditing ? 'Update Connection' : 'Save Connection'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
