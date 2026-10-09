import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brand = Color(0xFF123D32);
  static const brandDark = Color(0xFF78C3A2);
  static const ink = Color(0xFF151B18);
  static const canvas = Color(0xFFF7F4EE);
  static const surface = Colors.white;
  static const muted = Color(0xFF67716C);
  static const line = Color(0xFFDDD8CE);
  static const darkCanvas = Color(0xFF0C1210);
  static const darkSurface = Color(0xFF111A16);
  static const darkLine = Color(0xFF29352F);
  static const deep = Color(0xFF0B2A22);
  static const interactive = Color(0xFF185644);
  static const warm = Color(0xFFEFEAE0);
  static const subtle = Color(0xFF89918D);
  static const strongLine = Color(0xFFCBC4B8);
  static const brass = Color(0xFFB59660);
  static const darkRaised = Color(0xFF16221C);
  static const darkInk = Color(0xFFF4F1E9);
  static const darkMuted = Color(0xFFADB5B0);
  static const warning = Color(0xFF8A5B14);
}

abstract final class AppSpace {
  static const xxs = 4.0,
      xs = 8.0,
      sm = 12.0,
      md = 16.0,
      lg = 24.0,
      xl = 32.0,
      xxl = 48.0,
      huge = 64.0,
      display = 96.0;
}

abstract final class AppRadius {
  static const sm = 10.0, md = 12.0, lg = 16.0, xl = 24.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160),
      normal = Duration(milliseconds: 180);
}

abstract final class AppIconSize {
  static const sm = 18.0, md = 22.0, lg = 28.0;
}

abstract final class AppBreakpoints {
  static const compact = 420.0, tablet = 720.0;
}
