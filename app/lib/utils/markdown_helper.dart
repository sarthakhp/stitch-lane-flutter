class MarkdownHelper {
  static String stripMarkdown(String markdown) {
    if (markdown.isEmpty) return markdown;

    String result = markdown;

    result = result.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (match) => match.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      RegExp(r'__(.+?)__'),
      (match) => match.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      RegExp(r'\*(.+?)\*'),
      (match) => match.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      RegExp(r'_(.+?)_'),
      (match) => match.group(1) ?? '',
    );

    result = result.replaceAllMapped(
      RegExp(r'~~(.+?)~~'),
      (match) => match.group(1) ?? '',
    );

    result = result.replaceAllMapped(
      RegExp(r'`(.+?)`'),
      (match) => match.group(1) ?? '',
    );

    result = result.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');

    result = result.replaceAll(RegExp(r'^>\s+', multiLine: true), '');

    result = result.replaceAll(RegExp(r'^[\-\*\+]\s+', multiLine: true), '');

    result = result.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');

    result = result.replaceAllMapped(
      RegExp(r'\[(.+?)\]\(.+?\)'),
      (match) => match.group(1) ?? '',
    );

    result = result.replaceAllMapped(
      RegExp(r'!\[(.+?)\]\(.+?\)'),
      (match) => match.group(1) ?? '',
    );

    result = result.replaceAll(RegExp(r'^[\-\*_]{3,}$', multiLine: true), '');

    result = result.replaceAll(RegExp(r'\n{2,}'), '\n');

    result = result.replaceAll(RegExp(r' {2,}'), ' ');

    return result.trim();
  }

  static String getPreviewText(String markdown, {int maxLength = 150}) {
    final stripped = stripMarkdown(markdown);
    if (stripped.length <= maxLength) {
      return stripped;
    }
    return '${stripped.substring(0, maxLength)}...';
  }
}

