// lib/widgets/floating_nav_menu.dart
// Floating circular action menu — radial arc from bottom-right corner.
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../config/app_theme.dart';

class FloatingNavMenu extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const FloatingNavMenu({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  State<FloatingNavMenu> createState() => _FloatingNavMenuState();
}

class _FloatingNavMenuState extends State<FloatingNavMenu>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  static const _icons = [
    Icons.dashboard,
    Icons.bed,
    Icons.receipt_long,
    Icons.checklist,
    Icons.trending_up,
    Icons.chat,
    Icons.shield,
    Icons.notifications,
  ];

  static const _labels = [
    'Dashboard', 'Rooms', 'Masareef', 'Tasks',
    'Op. Costs', 'WhatsApp', 'Ta2meen', 'Alerts',
  ];

  // Number of visible items in the arc
  static const int _itemCount = 8;
  static const double _radius = 110.0;
  static const double _itemSize = 48.0;
  static const double _fabSize = 56.0;
  static const EdgeInsets _margin = EdgeInsets.only(right: 16, bottom: 16);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
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
    final screenSize = MediaQuery.of(context).size;
    final fabRight = _margin.right + _fabSize / 2;
    final fabBottom = _margin.bottom + _fabSize / 2;

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Scrim
          if (_open)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggle,
                child: AnimatedOpacity(
                  opacity: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(color: Colors.black),
                ),
              ),
            ),

          // Menu items in a radial arc
          ...List.generate(_itemCount, (i) {
            // Calculate position in a 160-degree arc (from -170 to -10 degrees)
            // This spreads items from bottom-left to top-left of the FAB
            final startAngle = -170.0 * math.pi / 180; // start from lower-left
            final endAngle = -10.0 * math.pi / 180;   // end at upper-left
            final angle = startAngle + (endAngle - startAngle) * (i / (_itemCount - 1));

            final centerX = screenSize.width - fabRight;
            final centerY = screenSize.height - fabBottom;

            return AnimatedBuilder(
              animation: _anim,
              builder: (context, child) {
                final p = _anim.value;
                final x = centerX + _radius * math.cos(angle) * p;
                final y = centerY + _radius * math.sin(angle) * p;

                return Positioned(
                  left: x - _itemSize / 2,
                  top: y - _itemSize / 2,
                  child: Opacity(
                    opacity: p,
                    child: Transform.scale(
                      scale: 0.5 + 0.5 * p,
                      child: _buildItem(i),
                    ),
                  ),
                );
              },
            );
          }),

          // Main FAB
          Positioned(
            right: _margin.right,
            bottom: _margin.bottom,
            child: GestureDetector(
              onTap: _toggle,
              child: Container(
                width: _fabSize,
                height: _fabSize,
                decoration: BoxDecoration(
                  color: _open ? AppColors.danger : AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _open ? Icons.close : Icons.grid_view_rounded,
                      key: ValueKey(_open),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(int i) {
    final isSelected = widget.selectedIndex == i;

    return GestureDetector(
      onTap: () {
        widget.onSelect(i);
        _toggle();
      },
      child: Tooltip(
        message: _labels[i],
        child: Container(
          width: _itemSize,
          height: _itemSize,
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
          child: Icon(
            _icons[i],
            size: 22,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
