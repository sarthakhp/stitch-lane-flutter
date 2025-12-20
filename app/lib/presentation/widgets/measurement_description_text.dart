import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class MeasurementDescriptionText extends StatelessWidget {
  final String text;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextStyle? baseStyle;

  const MeasurementDescriptionText({
    super.key,
    required this.text,
    this.maxLines,
    this.overflow,
    this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: AppConfig.measurementDescriptionFontSize,
    );
    final effectiveStyle = baseStyle ?? defaultStyle;

    return Text.rich(
      _buildTextSpan(effectiveStyle),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  TextSpan _buildTextSpan(TextStyle? baseStyle) {
    final numberPattern = RegExp(r'\d+\.?\d*');
    final spans = <TextSpan>[];
    int lastMatchEnd = 0;

    for (final match in numberPattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      spans.add(TextSpan(
        text: match.group(0),
        style: baseStyle?.copyWith(fontWeight: FontWeight.bold),
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans);
  }
}

