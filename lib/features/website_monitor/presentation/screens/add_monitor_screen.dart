import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/website_monitor.dart';
import '../providers/monitor_provider.dart';

class AddMonitorScreen extends ConsumerStatefulWidget {
  const AddMonitorScreen({super.key});

  @override
  ConsumerState<AddMonitorScreen> createState() => _AddMonitorScreenState();
}

class _AddMonitorScreenState extends ConsumerState<AddMonitorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _portController = TextEditingController(text: '80');
  MonitorType _type = MonitorType.http;
  int _interval = 60;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    String url = _urlController.text.trim();
    if (_type == MonitorType.http && !url.startsWith('http')) {
      url = 'https://$url';
    }

    final monitor = WebsiteMonitor(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      url: url,
      type: _type,
      checkIntervalSeconds: _interval,
      port: _type == MonitorType.port ? int.tryParse(_portController.text) : null,
    );

    ref.read(monitorsProvider.notifier).addMonitor(monitor);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Monitor'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Monitor Type', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<MonitorType>(
              segments: const [
                ButtonSegment(value: MonitorType.http, label: Text('HTTP(S)'), icon: Icon(Icons.language)),
                ButtonSegment(value: MonitorType.ping, label: Text('Ping'), icon: Icon(Icons.cell_tower)),
                ButtonSegment(value: MonitorType.port, label: Text('Port'), icon: Icon(Icons.radar)),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'e.g., Google, My API',
                prefixIcon: Icon(Icons.label),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: _type == MonitorType.http ? 'URL' : 'Host / IP',
                hintText: _type == MonitorType.http ? 'https://example.com' : '192.168.1.1',
                prefixIcon: Icon(_type == MonitorType.http ? Icons.link : Icons.dns),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            if (_type == MonitorType.port) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  prefixIcon: Icon(Icons.settings_input_component),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 24),
            Text('Check Interval', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [30, 60, 120, 300, 600].map((s) {
                final label = s < 60 ? '${s}s' : '${s ~/ 60}m';
                return ChoiceChip(
                  label: Text(label),
                  selected: _interval == s,
                  onSelected: (_) => setState(() => _interval = s),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.add),
              label: const Text('Add Monitor'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}
