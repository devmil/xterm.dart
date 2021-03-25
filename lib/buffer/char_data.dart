import 'package:xterm/renderer/renderer.dart';

class CharData {
  int attribute;
  String rune;
  int width;
  int code;

  CharData(this.attribute,
      {this.rune = '\u0200', this.width = 1, this.code = 0});

  // ((int)flags << 18) | (fg << 9) | bg;
  static const int DefaultAttr = Renderer.DefaultColor << 9 | (256 << 0);
  static const int InvertedAttr = Renderer.InvertedDefaultColor << 9 |
      (256 << 0) |
      Renderer.InvertedDefaultColor;

  static CharData nul =
      new CharData(DefaultAttr, rune: '\u0200', width: 1, code: 0);
  static CharData whiteSpace =
      new CharData(DefaultAttr, rune: ' ', width: 1, code: 32);
  static CharData leftBrace =
      new CharData(DefaultAttr, rune: '{', width: 1, code: 123);
  static CharData rightBrace =
      new CharData(DefaultAttr, rune: '}', width: 1, code: 125);
  static CharData leftBracket =
      new CharData(DefaultAttr, rune: '[', width: 1, code: 91);
  static CharData rightBracket =
      new CharData(DefaultAttr, rune: ']', width: 1, code: 93);
  static CharData leftParenthesis =
      new CharData(DefaultAttr, rune: '(', width: 1, code: 40);
  static CharData rightParenthesis =
      new CharData(DefaultAttr, rune: ')', width: 1, code: 41);
  static CharData period =
      new CharData(DefaultAttr, rune: '.', width: 1, code: 46);

  /// Returns true if this CharData matches the given Rune, irrespective of character attributes
  bool matchesRune(String rune) {
    return this.rune == rune;
  }

  /// Returns true if this CharData matches the given Rune, irrespective of character attributes
  bool matchesRuneOfCharData(CharData chr) {
    return rune == chr.rune;
  }

  bool isNullChar() {
    return rune == nul.rune || code == 0;
  }
}
