import 'package:flutter_test/flutter_test.dart';
import 'package:science_signal/trivia.dart';

void main() {
  test('decodes percent-encoded trivia text', () {
    expect(decodeTriviaText('Science%20%26%20Nature'), 'Science & Nature');
  });

  test('rejects malformed percent encoding', () {
    expect(() => decodeTriviaText('%ZZ'), throwsFormatException);
  });
}
