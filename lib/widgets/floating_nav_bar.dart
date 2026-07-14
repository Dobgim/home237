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

/// A floating, rounded "pill" bottom navigation bar.
///
/// Sits above the bottom edge on a dark navy bar; the selected tab expands into
/// a gold pill showing its icon + label, unselected tabs are icon-only. Matches
/// the Home237 Navy & Gold identity.
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

  static const Color _bar = Color(0xFF0F1E38); // deep navy bar
  static const Color _gold = Color(0xFFCA8A04); // active pill
  static const Color _onGold = Color(0xFF0F172A); // text/icon on gold
  static const Color _inactive = Colors.white70;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _bar,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        // FittedBox scales the whole row down on very narrow screens instead
        // of overflowing, so 5–6 tabs stay on one line everywhere.
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(items.length, (i) {
                final item = items[i];
                final active = i == currentIndex;
                final color = active ? _onGold : _inactive;
                final iconWidget = item.iconBuilder != null
                    ? item.iconBuilder!(active, color)
                    : Icon(active ? item.activeIcon : item.icon,
                        color: color, size: 22);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: active
                        ? const EdgeInsets.symmetric(horizontal: 15, vertical: 9)
                        : const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: active ? _gold : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        iconWidget,
                        if (active) ...[
                          const SizedBox(width: 8),
                          Text(
                            item.label,
                            style: const TextStyle(
                              color: _onGold,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
