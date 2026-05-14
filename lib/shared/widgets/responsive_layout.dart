import 'package:flutter/material.dart';

/// Returns true when the screen should render in mobile mode (narrow width).
bool isMobileWidth(BuildContext context) => MediaQuery.sizeOf(context).width < 700;

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key, required this.mobile, required this.desktop});
  final Widget mobile;
  final Widget desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return constraints.maxWidth < 700 ? mobile : desktop;
      },
    );
  }
}
