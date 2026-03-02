import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/themes/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<Map<String, dynamic>> _tabs = [
    {'icon': Icons.dashboard_outlined, 'active': Icons.dashboard, 'label': 'Console'},
    {'icon': Icons.link_outlined, 'active': Icons.link, 'label': 'Connect'},
    {'icon': Icons.monitor_heart_outlined, 'active': Icons.monitor_heart, 'label': 'Monitors'},
    {'icon': Icons.build_outlined, 'active': Icons.build, 'label': 'Tools'},
    {'icon': Icons.settings_outlined, 'active': Icons.settings, 'label': 'Settings'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF040609).withAlpha(180) : const Color(0xFFF8FAFC).withAlpha(200),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF1E293B).withAlpha(150) : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              final isSelected = currentIndex == index;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (isSelected)
                                Container(
                                  width: 40,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppTheme.cyan.withAlpha(25),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(color: AppTheme.cyan.withAlpha(40), blurRadius: 10, spreadRadius: -2)
                                    ],
                                  ),
                                ),
                              Icon(
                                isSelected ? tab['active'] : tab['icon'],
                                color: isSelected ? AppTheme.cyan : (isDark ? Colors.white54 : Colors.black54),
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedOpacity(
                          opacity: isSelected ? 1.0 : 0.6,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            tab['label'],
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isSelected ? AppTheme.cyan : (isDark ? Colors.white54 : Colors.black54),
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
