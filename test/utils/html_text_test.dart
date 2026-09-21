import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/utils/html_text.dart';

void main() {
  test('paragraphs, lists and entities', () {
    expect(
      htmlToText(
        '<p>Open from 7&nbsp;to 22 hours</p><ul><li>Towel &amp; lock</li><li>Clean shoes</li></ul>',
      ),
      'Open from 7 to 22 hours\n\n• Towel & lock\n• Clean shoes',
    );
  });

  test('script and style disappear together with their content', () {
    expect(htmlToText('<style>p{color:red}</style><p>Hi</p><script>alert(1)</script>'), 'Hi');
  });

  test('named and numeric entities', () {
    expect(
      htmlToText('Judo for every employ&eacute;&eacute;: one of the most versatile sports'),
      'Judo for every employéé: one of the most versatile sports',
    );
    expect(
      htmlToText('caf&#233; n&#xE9;&#xe9; &euro;5 &ndash; &ldquo;top&rdquo; rock &apos;n roll'),
      'café néé €5 – “top” rock \'n roll',
    );
  });

  test('unknown or broken entities are left as they are', () {
    expect(
      htmlToText('AT&T &doesnotexist; &#99999999; R&D;'),
      'AT&T &doesnotexist; &#99999999; R&D;',
    );
  });

  test('&amp;eacute; is decoded once, not twice', () {
    expect(htmlToText('&amp;eacute;'), '&eacute;');
  });

  test('plain text stays what it was', () {
    expect(htmlToText('Just text'), 'Just text');
  });
}
