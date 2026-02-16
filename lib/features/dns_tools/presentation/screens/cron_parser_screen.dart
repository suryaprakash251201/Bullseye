import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/themes/app_theme.dart';

class CronParserScreen extends StatefulWidget {
  const CronParserScreen({super.key});

  @override
  State<CronParserScreen> createState() => _CronParserScreenState();
}

class _CronParserScreenState extends State<CronParserScreen> {
  final _cronController = TextEditingController(text: '*/5 * * * *');
  String _description = '';
  List<String> _nextRuns = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _parse();
  }

  void _parse() {
    final expr = _cronController.text.trim();
    if (expr.isEmpty) return;

    final parts = expr.split(RegExp(r'\s+'));
    if (parts.length < 5 || parts.length > 6) {
      setState(() {
        _error = 'Invalid cron expression (expected 5 or 6 fields)';
        _description = '';
        _nextRuns = [];
      });
      return;
    }

    try {
      final desc = _buildDescription(parts);
      final next = _computeNextRuns(parts, 5);
      setState(() {
        _description = desc;
        _nextRuns = next;
        _error = '';
      });
    } catch (e) {
      setState(() {
        _error = 'Parse error: $e';
        _description = '';
        _nextRuns = [];
      });
    }
  }

  String _buildDescription(List<String> parts) {
    final minute = parts[0];
    final hour = parts[1];
    final dom = parts[2];
    final month = parts[3];
    final dow = parts[4];

    final buffer = StringBuffer('Runs ');

    // Minute
    if (minute == '*') {
      buffer.write('every minute');
    } else if (minute.startsWith('*/')) {
      buffer.write('every ${minute.substring(2)} minutes');
    } else {
      buffer.write('at minute $minute');
    }

    // Hour
    if (hour == '*') {
      buffer.write(', every hour');
    } else if (hour.startsWith('*/')) {
      buffer.write(', every ${hour.substring(2)} hours');
    } else {
      buffer.write(', at ${hour.padLeft(2, '0')}:${minute == '*' ? '00' : minute.padLeft(2, '0')}');
    }

    // Day of month
    if (dom != '*') {
      if (dom.startsWith('*/')) {
        buffer.write(', every ${dom.substring(2)} days');
      } else {
        buffer.write(', on day $dom');
      }
    }

    // Month
    if (month != '*') {
      const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthNum = int.tryParse(month);
      if (monthNum != null && monthNum >= 1 && monthNum <= 12) {
        buffer.write(', in ${monthNames[monthNum]}');
      } else {
        buffer.write(', in month $month');
      }
    }

    // Day of week
    if (dow != '*') {
      const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      final dayNum = int.tryParse(dow);
      if (dayNum != null && dayNum >= 0 && dayNum <= 6) {
        buffer.write(', on ${dayNames[dayNum]}');
      } else {
        buffer.write(', on day-of-week $dow');
      }
    }

    return buffer.toString();
  }

  List<String> _computeNextRuns(List<String> parts, int count) {
    // Simple next-run computation for basic patterns
    final now = DateTime.now();
    final results = <String>[];

    try {
      final minuteSpec = _parseField(parts[0], 0, 59);
      final hourSpec = _parseField(parts[1], 0, 23);
      final domSpec = _parseField(parts[2], 1, 31);
      final monthSpec = _parseField(parts[3], 1, 12);
      final dowSpec = _parseField(parts[4], 0, 6);

      var candidate = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      candidate = candidate.add(const Duration(minutes: 1));

      int iterations = 0;
      while (results.length < count && iterations < 525600) {
        // max 1 year of minutes
        iterations++;
        if (monthSpec.contains(candidate.month) &&
            domSpec.contains(candidate.day) &&
            dowSpec.contains(candidate.weekday % 7) &&
            hourSpec.contains(candidate.hour) &&
            minuteSpec.contains(candidate.minute)) {
          results.add(_formatDateTime(candidate));
        }
        candidate = candidate.add(const Duration(minutes: 1));
      }
    } catch (_) {
      // If parsing fails, return empty
    }

    return results;
  }

  Set<int> _parseField(String field, int min, int max) {
    if (field == '*') {
      return Set.from(List.generate(max - min + 1, (i) => min + i));
    }

    final result = <int>{};

    for (final part in field.split(',')) {
      if (part.contains('/')) {
        // Step: */n or m-n/s
        final stepParts = part.split('/');
        final step = int.parse(stepParts[1]);
        int start = min;
        int end = max;
        if (stepParts[0] != '*') {
          if (stepParts[0].contains('-')) {
            final range = stepParts[0].split('-');
            start = int.parse(range[0]);
            end = int.parse(range[1]);
          } else {
            start = int.parse(stepParts[0]);
          }
        }
        for (int i = start; i <= end; i += step) {
          result.add(i);
        }
      } else if (part.contains('-')) {
        // Range: m-n
        final range = part.split('-');
        final start = int.parse(range[0]);
        final end = int.parse(range[1]);
        for (int i = start; i <= end; i++) {
          result.add(i);
        }
      } else {
        // Single value
        result.add(int.parse(part));
      }
    }

    return result;
  }

  String _formatDateTime(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month]} ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _cronController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Cron Parser')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cron field labels
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['MIN', 'HOUR', 'DOM', 'MON', 'DOW'].map((l) {
                return Text(l, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey, letterSpacing: 1));
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _cronController,
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(fontSize: 22, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '*/5 * * * *',
              hintStyle: GoogleFonts.jetBrainsMono(fontSize: 22, color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
            onChanged: (_) => _parse(),
          ),
          const SizedBox(height: 12),

          // Quick presets
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Preset('Every minute', '* * * * *'),
              _Preset('Every 5 min', '*/5 * * * *'),
              _Preset('Every hour', '0 * * * *'),
              _Preset('Every day @ midnight', '0 0 * * *'),
              _Preset('Every Monday', '0 0 * * 1'),
              _Preset('1st of month', '0 0 1 * *'),
              _Preset('Every 30 min', '*/30 * * * *'),
              _Preset('Weekdays 9am', '0 9 * * 1-5'),
            ].map((p) => ActionChip(
                  label: Text(p.label, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    _cronController.text = p.expression;
                    _parse();
                  },
                )).toList(),
          ),
          const SizedBox(height: 20),

          // Error
          if (_error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_error, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
            ),

          // Description
          if (_description.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.primary.withAlpha(30)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_description, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                  ),
                ],
              ),
            ),

          // Next runs
          if (_nextRuns.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Next ${_nextRuns.length} runs:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey)),
            const SizedBox(height: 8),
            ...List.generate(_nextRuns.length, (i) {
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _nextRuns[i],
                        style: GoogleFonts.jetBrainsMono(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _Preset {
  final String label;
  final String expression;
  _Preset(this.label, this.expression);
}
