import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class Base64ToolScreen extends StatefulWidget {
  const Base64ToolScreen({super.key});

  @override
  State<Base64ToolScreen> createState() => _Base64ToolScreenState();
}

class _Base64ToolScreenState extends State<Base64ToolScreen> with SingleTickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _outputController = TextEditingController();
  late TabController _tabController;
  bool _isUrl = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      _inputController.clear();
      _outputController.clear();
    });
  }

  void _encode() {
    final input = _inputController.text;
    if (input.isEmpty) return;

    try {
      String encoded;
      if (_isUrl) {
        encoded = Uri.encodeFull(input);
      } else {
        encoded = base64Encode(utf8.encode(input));
      }
      setState(() => _outputController.text = encoded);
    } catch (e) {
      setState(() => _outputController.text = 'Error: $e');
    }
  }

  void _decode() {
    final input = _inputController.text;
    if (input.isEmpty) return;

    try {
      String decoded;
      if (_isUrl) {
        decoded = Uri.decodeFull(input);
      } else {
        decoded = utf8.decode(base64Decode(input));
      }
      setState(() => _outputController.text = decoded);
    } catch (e) {
      setState(() => _outputController.text = 'Error: Invalid input');
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _outputController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Encode / Decode'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Encode'),
            Tab(text: 'Decode'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTab(context, isDark, isEncode: true),
          _buildTab(context, isDark, isEncode: false),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, bool isDark, {required bool isEncode}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Mode toggle
        Row(
          children: [
            ChoiceChip(
              label: const Text('Base64'),
              selected: !_isUrl,
              onSelected: (_) => setState(() => _isUrl = false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('URL Encode'),
              selected: _isUrl,
              onSelected: (_) => setState(() => _isUrl = true),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Input
        TextField(
          controller: _inputController,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: isEncode ? 'Plain Text' : (_isUrl ? 'URL Encoded' : 'Base64 String'),
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),

        FilledButton.icon(
          onPressed: isEncode ? _encode : _decode,
          icon: Icon(isEncode ? Icons.lock : Icons.lock_open, size: 18),
          label: Text(isEncode ? 'Encode' : 'Decode'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 16),

        // Output
        if (_outputController.text.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Output', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: 'Copy',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _outputController.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _outputController.text,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
