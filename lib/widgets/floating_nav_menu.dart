// lib/widgets/floating_nav_menu.dart
// Floating circular action menu — 3/4 circle in corner with icon-only items.
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class FloatingNavMenu extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const FloatingNavMenu({super.key, required this.selectedIndex, required this.onSelect});

  @override
  State<FloatingNavMenu> createState() => _FloatingNavMenuState();
}

class _FloatingNavMenuState extends State<FloatingNavMenu>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  static const _items = [
    _NavItem(Icons.dashboard, 'Dashboard'),
    _NavItem(Icons.bed, 'Rooms'),
    _NavItem(Icons.receipt_long, 'Masareef'),
    _NavItem(Icons.checklist, 'Tasks'),
    _NavItem(Icons.trending_up, 'Op. Costs'),
    _NavItem(Icons.chat, 'WhatsApp'),
    _NavItem(Icons.shield, 'Ta2meen'),
    _NavItem(Icons.notifications, 'Alerts'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Scrim when open
        if (_open)
          GestureDetector(
            onTap: _toggle,
            child: AnimatedOpacity(
              opacity: _open ? 0.4 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(color: Colors.black),
            ),
          ),

        // Radial menu items
        ...List.generate(_items.length, (i) {
          final angle = (180.0 / (_items.length - 1)) * i - 90; // spread across 180 degrees (3/4 circle)
          final rad = angle * 3.14159 / 180;
          final radius = 100.0;

          return AnimatedBuilder(
            animation: _anim,
            builder: (context, child) {
              final progress = _anim.value;
              final dx = _open ? (radius * progress * (i == 0 ? 0 : (i / _items.length) * 1.5)) : 0.0;
              final dy = _open ? (-radius * progress * (1.0 - (i / _items.length) * 0.5)) : 0.0;

              return Positioned(
                right: 20 + dx,
                bottom: 20 + dy,
                child: Opacity(
                  opacity: progress,
                  child: Transform.scale(
                    scale: progress,
                    child: _buildMenuItem(i),
                  ),
                ),
              );
            },
          );
        }),

        // Main FAB
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _toggle,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: AnimatedRotation(
              turns: _open ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(_open ? Icons.close : Icons.apps, size: 26),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(int i) {
    final item = _items[i];
    final isSelected = widget.selectedIndex == i;

    return GestureDetector(
      onTap: () {
        widget.onSelect(i);
        _toggle();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.borderMuted,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(item.icon,
            size: 22,
            color: isSelected ? Colors.white : AppColors.textSecondary),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
