import 'package:xterm/terminal/line_fragment.dart';

class Line {
  final _fragments = List<LineFragment>.empty(growable: true);
  int _length = 0;

  int get startLine => _fragments.length > 0 ? _fragments.first.line : 0;
  int get startLocation =>
      _fragments.length > 0 ? _fragments.first.location : 0;
  int get length => _length;

  add(LineFragment fragment) {
    _fragments.add(fragment);
    _length += fragment.length;
  }

  addFragmentStrings(StringBuffer buffer) {
    _fragments.forEach((element) {
      buffer.write(element.text);
    });
  }

  int getFragmentIndexForPosition(int pos) {
    int count = 0;
    for (int i = 0; i < _fragments.length; i++) {
      count += _fragments[i].length;
      if (count > pos) {
        return i;
      }
    }

    return _fragments.length - 1;
  }

  LineFragment getFragment(int index) {
    return _fragments[index];
  }
}
