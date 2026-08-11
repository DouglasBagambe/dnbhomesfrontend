import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brand = Color(0xFF176B48);
  static const brandDark = Color(0xFF78C6A3);
  static const ink = Color(0xFF17211D);
  static const canvas = Color(0xFFF7F8F6);
  static const surface = Colors.white;
  static const muted = Color(0xFF65716B);
  static const line = Color(0xFFE1E6E2);
  static const darkCanvas = Color(0xFF101512);
  static const darkSurface = Color(0xFF181F1B);
  static const darkLine = Color(0xFF2A342E);
  static const warning = Color(0xFF8A5B14);
}

abstract final class AppSpace {
  static const xxs = 4.0,
      xs = 8.0,
      sm = 12.0,
      md = 16.0,
      lg = 24.0,
      xl = 32.0,
      xxl = 48.0;
}

abstract final class AppRadius {
  static const sm = 8.0, md = 14.0, lg = 20.0, xl = 28.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160),
      normal = Duration(milliseconds: 240);
}

abstract final class AppIconSize {
  static const sm = 18.0, md = 22.0, lg = 28.0;
}

abstract final class AppBreakpoints {
  static const compact = 420.0, tablet = 720.0;
}
