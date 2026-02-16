import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto_lib;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class HashGeneratorScreen extends StatefulWidget {
  const HashGeneratorScreen({super.key});

  @override
  State<HashGeneratorScreen> createState() => _HashGeneratorScreenState();
}

class _HashGeneratorScreenState extends State<HashGeneratorScreen> {
  final _inputController = TextEditingController();
  final Map<String, String> _hashes = {};

  void _computeHashes() {
    final text = _inputController.text;
    if (text.isEmpty) {
      setState(() => _hashes.clear());
      return;
    }

    final bytes = utf8.encode(text);
    setState(() {
      _hashes['MD5'] = crypto_lib.md5.convert(bytes).toString();
      _hashes['SHA-1'] = crypto_lib.sha1.convert(bytes).toString();
      _hashes['SHA-224'] = crypto_lib.sha224.convert(bytes).toString();
      _hashes['SHA-256'] = crypto_lib.sha256.convert(bytes).toString();
      _hashes['SHA-384'] = crypto_lib.sha384.convert(bytes).toString();
      _hashes['SHA-512'] = crypto_lib.sha512.convert(bytes).toString();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Hash Generator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _inputController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Input Text',
              hintText: 'Enter text to hash...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onChanged: (_) => _computeHashes(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _computeHashes,
            icon: const Icon(Icons.tag, size: 20),
            label: const Text('Generate Hashes'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 24),
          if (_hashes.isNotEmpty)
            ..._hashes.entries.map((e) => _HashRow(
                  algorithm: e.key,
                  hash: e.value,
                  isDark: isDark,
                )),
        ],
      ),
    );
  }
}

class _HashRow extends StatelessWidget {
  final String algorithm;
  final String hash;
  final bool isDark;

  const _HashRow({required this.algorithm, required this.hash, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(algorithm, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: hash));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$algorithm hash copied'), duration: const Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            hash,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
          ),
        ],
      ),
    );
  }
}
