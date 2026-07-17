import 'dart:ui' as ui;
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

/// Home237's floating bottom navigation bar.
///
/// A clean white frosted pill floats above the bottom edge. The selected tab
/// expands into a gold pill (the app accent) with its icon + label; the other
/// tabs are quiet warm-gray glyphs. Hovering a tab (web/desktop) tints it
/// with the same gold — no blues anywhere.
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

  static const Color _accent = Color(0xFF1C1917); // deep charcoal — active pill
  static const Color _accentDark = Color(0xFF000000); // pill gradient end
  static const Color _onAccent = Colors.white; // icon/label on the pill
  static const Color _inactiveLight = Color(0xFF8A8577); // warm gray (no blue)
  static const Color _inactiveDark = Color(0xFFB8B3A6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark
        ? const Color(0xFF201F1C).withValues(alpha: 0.86)
        : Colors.white.withValues(alpha: 0.88);
    final inactive = isDark ? _inactiveDark : _inactiveLight;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(
                  color: (isDark ? Colors.white : const Color(0xFF1C1917))
                      .withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              // FittedBox scales the row down on very narrow screens instead
              // of overflowing, so 5–6 tabs stay on one line everywhere.
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(items.length, (i) {
                      final item = items[i];
                      final active = i == currentIndex;
                      final color = active ? _onAccent : inactive;
                      final iconWidget = item.iconBuilder != null
                          ? item.iconBuilder!(active, color)
                          : Icon(active ? item.activeIcon : item.icon,
                              color: color, size: 22);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(28),
                          child: InkWell(
                            onTap: () => onTap(i),
                            borderRadius: BorderRadius.circular(28),
                            // Hover/press feedback in the SAME gold accent.
                            hoverColor: _accent.withValues(alpha: 0.12),
                            splashColor: _accent.withValues(alpha: 0.18),
                            highlightColor: _accent.withValues(alpha: 0.10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              padding: active
                                  ? const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 11)
                                  : const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                gradient: active
                                    ? const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [_accent, _accentDark],
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                          color: _accent.withValues(alpha: 0.30),
                                          blurRadius: 12,
                                          offset: const Offset(0, 5),
                                        ),
                                      ]
                                    : null,
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
                                        color: _onAccent,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
