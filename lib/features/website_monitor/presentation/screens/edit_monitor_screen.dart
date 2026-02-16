import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/website_monitor.dart';
import '../providers/monitor_provider.dart';

class EditMonitorScreen extends ConsumerStatefulWidget {
  final WebsiteMonitor monitor;
  const EditMonitorScreen({super.key, required this.monitor});

  @override
  ConsumerState<EditMonitorScreen> createState() => _EditMonitorScreenState();
}

class _EditMonitorScreenState extends ConsumerState<EditMonitorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _portController;
  late MonitorType _type;
  late int _interval;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.monitor.name);
    _urlController = TextEditingController(text: widget.monitor.url);
    _portController = TextEditingController(text: widget.monitor.port?.toString() ?? '80');
    _type = widget.monitor.type;
    _interval = widget.monitor.checkIntervalSeconds;
  }

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

    final updatedMonitor = widget.monitor.copyWith(
      name: _nameController.text.trim(),
      url: url,
      type: _type,
      checkIntervalSeconds: _interval,
      port: _type == MonitorType.port ? int.tryParse(_portController.text) : null,
    );

    ref.read(monitorsProvider.notifier).updateMonitor(updatedMonitor);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Monitor'),
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
                prefixIcon: Icon(Icons.label),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: _type == MonitorType.http ? 'URL' : 'Host / IP',
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
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}
