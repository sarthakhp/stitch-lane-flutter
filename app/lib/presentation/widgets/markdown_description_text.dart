import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class MarkdownDescriptionText extends StatelessWidget {
  final String text;
  final bool selectable;

  const MarkdownDescriptionText({
    super.key,
    required this.text,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MarkdownBody(
      data: text,
      selectable: selectable,
      styleSheet: MarkdownStyleSheet(
        p: theme.textTheme.bodyLarge,
        strong: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        em: theme.textTheme.bodyLarge?.copyWith(
          fontStyle: FontStyle.italic,
        ),
        listBullet: theme.textTheme.bodyLarge,
        listIndent: 16.0,
        blockSpacing: 8.0,
        h1: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        h2: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        h3: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}

