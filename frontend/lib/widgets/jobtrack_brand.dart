import 'package:flutter/material.dart';

import '../theme/jobtrack_theme.dart';

class JobTrackBrand extends StatelessWidget {
  const JobTrackBrand({
    super.key,
    this.logoSize = 32,
    this.showText = true,
    this.textStyle,
  });

  static const String assetPath = 'assets/image/jobtrack.png';

  final double logoSize;
  final bool showText;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          assetPath,
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.work_outline,
            size: logoSize * 0.8,
            color: JobTrackColors.blue,
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            'JobTrack',
            style:
                textStyle ??
                const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: JobTrackColors.navy,
                  letterSpacing: -0.3,
                ),
          ),
        ],
      ],
    );
  }
}
