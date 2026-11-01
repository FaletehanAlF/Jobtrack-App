import 'package:flutter/material.dart';

class JobTrackColors {
  static const Color navy = Color(0xFF0F2137);

  static const Color navyMuted = Color(0xFF5A6B7B);

  static const Color blue = Color(0xFF1F6FEB);

  static const Color blueSoft = Color(0xFFEAF2FF);

  static const Color background = Color(0xFFF7F9FB);

  static const Color surface = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE2E8F0);

  static const Color borderStrong = Color(0xFFD3DCE6);

  static const Color danger = Color(0xFFB42318);

  static const Color dangerSoft = Color(0xFFFDECEA);

  static const Color dangerBorder = Color(0xFFF3C6C1);

  static const Color hint = Color(0xFF9AA7B4);

  static const Color disabled = Color(0xFFB9C6D3);


  static const LinearGradient authGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [authBackgroundTop, authBackgroundBottom],
  );

  static const Color authBackgroundTop = Color(0xFFEEF3F9);

  static const Color authBackgroundBottom = Color(0xFFE3EBF5);

  static const Color authBorder = Color(0xFFD9E1EA);

  static const Color authAvatarBackground = Color(0xFFF1F5FA);
}

class JobTrackRadii {
  static const double field = 12;

  static const double button = 28;

  static const double banner = 14;

  static const double social = 28;
}
