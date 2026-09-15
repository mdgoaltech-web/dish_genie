import 'package:flutter/material.dart';

/// Minimal Markdown rendering for AI Chef replies.
///
/// The chat model answers with light Markdown: `**bold**`, `*italic*`,
/// `# headings`, `* ` / `- ` bullets and numbered lists. Showing the raw
/// asterisks looks broken, so this converts the subset we actually receive
/// into styled [TextSpan]s. Anything else is left untouched.
class ChatMarkdown {
  ChatMarkdown._();

  static final RegExp _heading = RegExp(r'^\s{0,3}#{1,6}\s+');
  static final RegExp _bullet = RegExp(r'^(\s*)[*\-•]\s+');
  static final RegExp _emphasis = RegExp(
    r'(\*\*|__)(.+?)\1|(?<![\w*])(\*|_)(?!\s)(.+?)(?<!\s)\3(?![\w*])',
  );

  /// Plain text with the Markdown markers removed (for copy/share).
  static String toPlainText(String markdown) {
    final buffer = StringBuffer();
    for (final span in spans(markdown, const TextStyle())) {
      buffer.write(span.toPlainText());
    }
    return buffer.toString();
  }

  /// Styled spans for [markdown] using [base] as the body style.
  static List<TextSpan> spans(String markdown, TextStyle base) {
    final out = <TextSpan>[];
    final lines = markdown.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var style = base;
      if (_heading.hasMatch(line)) {
        line = line.replaceFirst(_heading, '');
        style = base.copyWith(fontWeight: FontWeight.w700);
      } else {
        final bullet = _bullet.firstMatch(line);
        if (bullet != null) {
          line = '${bullet.group(1)}• ${line.substring(bullet.end)}';
        }
      }
      out.addAll(_inline(line, style));
      if (i < lines.length - 1) out.add(TextSpan(text: '\n', style: base));
    }
    return out;
  }

  static List<TextSpan> _inline(String line, TextStyle style) {
    final out = <TextSpan>[];
    var cursor = 0;
    for (final m in _emphasis.allMatches(line)) {
      if (m.start > cursor) {
        out.add(TextSpan(text: line.substring(cursor, m.start), style: style));
      }
      final strong = m.group(2);
      if (strong != null) {
        out.add(
          TextSpan(
            text: strong,
            style: style.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else {
        out.add(
          TextSpan(
            text: m.group(4),
            style: style.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      cursor = m.end;
    }
    if (cursor < line.length) {
      out.add(TextSpan(text: line.substring(cursor), style: style));
    }
    return out;
  }
}
