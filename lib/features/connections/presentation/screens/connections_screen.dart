import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/connection_profile.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../ssh/presentation/screens/ssh_client_screen.dart';
import '../../../ftp/presentation/screens/ftp_client_screen.dart';
import '../providers/connections_provider.dart';
import 'add_connection_screen.dart';

class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // ignore: prefer_final_fields
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connections = ref.watch(connectionsProvider);

    final filtered = _searchQuery.isEmpty
        ? connections
        : connections.where((c) =>
            c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.host.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final sshConns = filtered.where((c) => c.type == ConnectionType.ssh).toList();
    final ftpConns = filtered.where((c) => c.type == ConnectionType.ftp).toList();
    final sftpConns = filtered.where((c) => c.type == ConnectionType.sftp).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final selected = await showSearch<ConnectionProfile?>(
                context: context,
                delegate: _ConnectionSearchDelegate(connections),
              );

              if (!context.mounted || selected == null) return;
              await _openConnection(context, ref, selected);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'All (${filtered.length})'),
            Tab(text: 'SSH (${sshConns.length})'),
            Tab(text: 'FTP (${ftpConns.length})'),
            Tab(text: 'SFTP (${sftpConns.length})'),
          ],
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(120),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ConnectionList(connections: filtered),
          _ConnectionList(connections: sshConns),
          _ConnectionList(connections: ftpConns),
          _ConnectionList(connections: sftpConns),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddConnectionScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Connection'),
      ),
    );
  }
}

class _ConnectionList extends ConsumerWidget {
  final List<ConnectionProfile> connections;

  const _ConnectionList({required this.connections});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (connections.isEmpty) {
      return const EmptyState(
        icon: Icons.cable_outlined,
        title: 'No connections found',
        subtitle: 'Add a new SSH, FTP, or SFTP connection',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: connections.length,
      itemBuilder: (context, index) {
        final conn = connections[index];
        return _ConnectionTile(connection: conn);
      },
    );
  }
}

class _ConnectionTile extends ConsumerWidget {
  final ConnectionProfile connection;

  const _ConnectionTile({required this.connection});

  IconData _getIcon() {
    switch (connection.type) {
      case ConnectionType.ssh:
        return Icons.terminal;
      case ConnectionType.ftp:
        return Icons.folder_open;
      case ConnectionType.sftp:
        return Icons.folder_special;
    }
  }

  Color _getColor() {
    switch (connection.type) {
      case ConnectionType.ssh:
        return Colors.blueGrey;
      case ConnectionType.ftp:
        return Colors.deepPurple;
      case ConnectionType.sftp:
        return AppTheme.teal;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = _getColor();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_getIcon(), color: color, size: 22),
        ),
        title: Text(
          connection.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(connection.connectionString),
            if (connection.lastConnectedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Last connected ${_formatLastConnected(connection.lastConnectedAt!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withAlpha(120),
                  ),
                ),
              ),
            if (connection.group != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    connection.group!,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'connect':
                _connect(context, ref);
                break;
              case 'edit':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddConnectionScreen(editConnection: connection),
                  ),
                );
                break;
              case 'delete':
                _confirmDelete(context, ref);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'connect', child: Text('Connect')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: AppTheme.error)),
            ),
          ],
        ),
        onTap: () => _connect(context, ref),
      ),
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    await _openConnection(context, ref, connection);
  }

  String _formatLastConnected(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    final months = (diff.inDays / 30).floor();
    return '${months}mo ago';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Connection'),
        content: Text('Delete "${connection.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(connectionsProvider.notifier).removeConnection(connection.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionSearchDelegate extends SearchDelegate<ConnectionProfile?> {
  final List<ConnectionProfile> connections;

  _ConnectionSearchDelegate(this.connections);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList();
  
  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final filtered = connections.where((c) =>
        c.name.toLowerCase().contains(query.toLowerCase()) ||
        c.host.toLowerCase().contains(query.toLowerCase())).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final conn = filtered[index];
        return ListTile(
          leading: Icon(
            conn.type == ConnectionType.ssh ? Icons.terminal : Icons.folder_shared,
          ),
          title: Text(conn.name),
          subtitle: Text(conn.connectionString),
          onTap: () => close(context, conn),
        );
      },
    );
  }
}

Future<void> _openConnection(
  BuildContext context,
  WidgetRef ref,
  ConnectionProfile connection,
) async {
  await ref.read(connectionsProvider.notifier).updateLastConnected(connection.id);

  if (!context.mounted) return;

  switch (connection.type) {
    case ConnectionType.ssh:
    case ConnectionType.sftp:
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SSHClientScreen(
            initialConnection: connection,
            autoConnect: true,
          ),
        ),
      );
      break;
    case ConnectionType.ftp:
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FTPClientScreen(
            initialConnection: connection,
            autoConnect: true,
          ),
        ),
      );
      break;
  }
}
