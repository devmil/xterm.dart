class LineFragment {
  final int _line;
  int get line => _line;
  final int _location;
  int get location => _location;
  final String _text;
  String get text => _text;
  final int _length;
  int get length => _length;

  LineFragment(this._text, this._line, this._location) : _length = _text.length;

  static LineFragment newLine(int line) => LineFragment('\n', line, -1);
}
