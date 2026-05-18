import 'package:flutter/material.dart';

/// Animated waveform bars driven by amplitude levels.
class AudioWaveform extends StatelessWidget {
  final List<double> levels;
  final bool isPaused;

  // --- Visual config ---
  static const double barWidth = 4.0;
  static const double barGap = 6.0;
  static const double maxBarHeight = 28.0;
  static const double minBarHeight = 2.0;

  const AudioWaveform({
    super.key,
    required this.levels,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: maxBarHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(levels.length, (i) {
          final raw = isPaused ? 0.0 : levels[i];
          // Square the level so low sounds stay short, only loud sounds spike
          final level = raw * raw;
          final barHeight = minBarHeight + level * (maxBarHeight - minBarHeight);
          final opacity = 0.3 + raw * 0.7;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: barGap / 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: barWidth,
              height: barHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    colorScheme.primary.withValues(alpha: opacity),
                    colorScheme.tertiary.withValues(alpha: opacity),
                  ],
                ),
                borderRadius: BorderRadius.circular(barWidth / 2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
