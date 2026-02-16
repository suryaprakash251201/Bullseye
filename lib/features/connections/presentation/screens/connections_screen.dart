import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/models/connection_profile.dart';

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

    final filtered = connections;

    final sshConns = filtered.where((c) => c.type == ConnectionType.ssh).toList();
    final ftpConns = filtered.where((c) => c.type == ConnectionType.ftp).toList();
    final sftpConns = filtered.where((c) => c.type == ConnectionType.sftp).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Connections', style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,fontWeight: FontWeight.w700)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(150),
              labelStyle: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,fontWeight: FontWeight.w600),
              padding: const EdgeInsets.all(6),
              tabs: [
                Tab(text: 'All (${filtered.length})'),
                Tab(text: 'SSH (${sshConns.length})'),
                Tab(text: 'FTP (${ftpConns.length})'),
                Tab(text: 'SFTP (${sftpConns.length})'),
              ],
            ),
          ),
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
        icon: const Icon(Icons.add_link),
        label: const Text('Add Connection'),
        elevation: 4,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hub_outlined, size: 60, color: Theme.of(context).colorScheme.primary.withAlpha(150)),
            ),
            const SizedBox(height: 24),
            Text(
              'No connections yet',
              style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a new SSH, FTP, or SFTP connection\nto get started.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: connections.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
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
        return const Color(0xFF2979FF); // Blue
      case ConnectionType.ftp:
        return const Color(0xFF7C4DFF); // Deep Purple
      case ConnectionType.sftp:
        return const Color(0xFF00BFA5); // Teal accent
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = _getColor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _connect(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_getIcon(), color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.name,
                        style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.link, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            connection.connectionString,
                            style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    PopupMenuItem(
                      value: 'connect',
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow_rounded, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 12),
                          const Text('Connect'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          const SizedBox(width: 12),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 12),
                          const Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    await _openConnection(context, ref, connection);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Connection'),
        content: Text('Delete "${connection.name}"? This cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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



