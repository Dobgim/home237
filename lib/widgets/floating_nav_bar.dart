import 'package:flutter/material.dart';

/// One tab in [FloatingNavBar].
///
/// For plain tabs give [icon]/[activeIcon]. For tabs that need a badge (unread
/// count etc.) provide [iconBuilder] — it receives whether the tab is active
/// and the colour to tint the glyph, and returns the finished icon widget.
class FloatingNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget Function(bool active, Color color)? iconBuilder;

  const FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.iconBuilder,
  });
}

/// Home237's bottom navigation bar — an Airbnb-style full-width tab bar.
///
/// A clean white (or dark) bar anchored to the bottom edge with a hairline
/// top border and a soft shadow. Each tab stacks its icon over a small label;
/// the active tab is tinted in the brand navy, the rest are a quiet gray. An
/// animated indicator underlines the active tab.
class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavItem> items;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  static const Color _active = Color(0xFF1E3A5F); // brand navy
  static const Color _inactiveLight = Color(0xFF717171); // Airbnb-style gray
  static const Color _inactiveDark = Color(0xFF9AA0A6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? const Color(0xFF16181C) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A2D33) : const Color(0xFFEBEBEB);
    final inactive = isDark ? _inactiveDark : _inactiveLight;
    final activeColor = isDark ? Colors.white : _active;

    return Container(
      decoration: BoxDecoration(
        color: barColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final active = i == currentIndex;
              final color = active ? activeColor : inactive;
              final iconWidget = item.iconBuilder != null
                  ? item.iconBuilder!(active, color)
                  : Icon(active ? item.activeIcon : item.icon,
                      color: color, size: 25);

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  splashColor: _active.withValues(alpha: 0.06),
                  highlightColor: _active.withValues(alpha: 0.04),
                  hoverColor: _active.withValues(alpha: 0.04),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      iconWidget,
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                        child: Text(item.label),
                      ),
                      const SizedBox(height: 4),
                      // Active-tab indicator dot.
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        height: 3,
                        width: active ? 18 : 0,
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
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
