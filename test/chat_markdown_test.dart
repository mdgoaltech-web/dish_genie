import 'package:dish_genie/widgets/chat/chat_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = TextStyle(fontSize: 14);

  test('bold markers become bold spans and are not shown', () {
    final spans = ChatMarkdown.spans('Use **fresh** basil', base);
    expect(spans.map((s) => s.text).join(), 'Use fresh basil');
    final bold = spans.firstWhere((s) => s.text == 'fresh');
    expect(bold.style?.fontWeight, FontWeight.w700);
    expect(spans.first.style?.fontWeight, isNot(FontWeight.w700));
  });

  test('italic markers become italic spans', () {
    final spans = ChatMarkdown.spans('a *quick* tip', base);
    expect(spans.map((s) => s.text).join(), 'a quick tip');
    final italic = spans.firstWhere((s) => s.text == 'quick');
    expect(italic.style?.fontStyle, FontStyle.italic);
  });

  test('bullets, numbered lists and headings render cleanly', () {
    const md = '## Ideas\n*   **Canola Oil:** neutral\n- Olive oil\n1.  Rice';
    final plain = ChatMarkdown.toPlainText(md);
    expect(plain, 'Ideas\n• Canola Oil: neutral\n• Olive oil\n1.  Rice');
  });

  test('plain text and emoji pass through untouched', () {
    const text = 'Happy baking! 🍪 2 * 3 = 6';
    expect(ChatMarkdown.toPlainText(text), text);
  });
}
