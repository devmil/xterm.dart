import 'dart:math';

import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/char_data.dart';
import 'package:xterm/terminal/line.dart';
import 'package:xterm/terminal/line_fragment.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:unicode/unicode.dart' as unicode;

class SelectionService {
  final Terminal _terminal;
  bool _isActive;
  Function()? onSelectionChanged;
  Point<int>? _start;
  Point<int>? _end;

  SelectionService(this._terminal) : _isActive = false;

  bool get isActive => _isActive;
  set isActive(bool value) {
    if (_isActive == value) {
      return;
    }
    _isActive = value;
    onSelectionChanged?.call();
  }

  Point<int>? get start => _start;
  Point<int>? get end => _end;

  startSelection(int row, int col) {
    _start = _end = Point<int>(col, row + _terminal.buffer.yDisp);
    _isActive = true;
    onSelectionChanged?.call();
  }

  restartSelection() {
    _end = _start;
    _isActive = true;
    onSelectionChanged?.call();
  }

  setSoftStart(int row, int col) {
    _start = _end = Point(col, row + _terminal.buffer.yDisp);
  }

  shiftExtend(int row, int col) {
    _isActive = true;
    final newEnd = Point(col, row + _terminal.buffer.yDisp);

    var shouldSwapStart = false;
    if (_comparePoints(start, end) < 0) {
      // start is before end, is the new end before Start
      if (_comparePoints(newEnd, start) < 0) {
        // yes, swap Start and End
        shouldSwapStart = true;
      }
    } else if (_comparePoints(start, end) > 0) {
      if (_comparePoints(newEnd, start) > 0) {
        // yes, swap Start and End
        shouldSwapStart = true;
      }
    }
    if (shouldSwapStart) {
      _start = _end;
    }

    _end = newEnd;
    onSelectionChanged?.call();
  }

  dragExtend(int row, int col) {
    _end = Point(col, row + _terminal.buffer.yDisp);
    onSelectionChanged?.call();
  }

  selectAll() {
    _start = Point(0, 0);
    _end = Point(_terminal.cols - 1, _terminal.buffer.lines.maxLength - 1);

    _isActive = true;
    onSelectionChanged?.call();
  }

  selectNone() {
    _isActive = false;
    onSelectionChanged?.call();
  }

  selectRow(int row) {
    _start = Point(0, row + _terminal.buffer.yDisp);
    _end = Point(_terminal.cols - 1, row + _terminal.buffer.yDisp);
    // set the field to bypass sending this event twice
    _isActive = true;
    onSelectionChanged?.call();
  }

  /// <summary>
  /// Selects a word or expression based on the col and row that the user sees on screen
  /// An expression is a balanced set parenthesis, braces or brackets
  /// </summary>
  selectWordOrExpression(int col, int row) {
    var buffer = _terminal.buffer;

    // ensure the bounds are inside the terminal.
    row = max(row, 0);
    col = max(min(col, _terminal.buffer.cols - 1), 0);

    row += buffer.yDisp;

    bool Function(CharData) isLetterOrChar = (CharData cd) {
      if (cd.isNullChar) {
        return false;
      }
      return unicode.isLetterNumber(cd.rune.runes.first);
    };

    final chr = buffer.getChar(col, row);
    if (chr.isNullChar) {
      _simpleScanSelection(col, row, (ch) => ch.isNullChar);
    } else {
      if (isLetterOrChar(chr)) {
        _simpleScanSelection(col, row, (ch) {
          return isLetterOrChar(ch) ||
              ch.matchesRuneOfCharData(CharData.period);
        });
      } else {
        if (chr.matchesRuneOfCharData(CharData.whiteSpace)) {
          _simpleScanSelection(col, row, (ch) {
            return ch.matchesRuneOfCharData(CharData.whiteSpace);
          });
        } else if (chr.matchesRuneOfCharData(CharData.leftBrace) ||
            chr.matchesRuneOfCharData(CharData.leftBracket) ||
            chr.matchesRuneOfCharData(CharData.leftParenthesis)) {
          _balancedSearchForward(col, row);
        } else if (chr.matchesRuneOfCharData(CharData.rightBrace) ||
            chr.matchesRuneOfCharData(CharData.rightBracket) ||
            chr.matchesRuneOfCharData(CharData.rightParenthesis)) {
          _balancedSearchBackward(col, row);
        } else {
          // For other characters, we just stop there
          _start = _end = Point(col, row + _terminal.buffer.yDisp);
        }
      }
    }

    _isActive = true;
    onSelectionChanged?.call();
  }

  String getSelectedText() {
    final lines = getSelectedLines();
    if (lines.length <= 0) {
      return "";
    }
    final buffer = StringBuffer();
    lines.forEach((line) {
      line.addFragmentStrings(buffer);
    });
    return buffer.toString();
  }

  bool contains(Point p) {
    if (!isActive) {
      return false;
    }
    if (_start!.y > p.y) {
      return false;
    }
    if (_end!.y < p.y) {
      return false;
    }
    if (_start!.y == p.y && _start!.x > p.x) {
      return false;
    }
    if (_end!.y == p.y && _end!.x < p.x) {
      return false;
    }
    return true;
  }

  List<Line> getSelectedLines() {
    var localStart = start;
    var localEnd = end;

    if (localStart == null || localEnd == null) {
      return List<Line>.empty();
    }

    switch (_comparePoints(localStart, localEnd)) {
      case 0:
        return List<Line>.empty();
      case 1:
        localStart = end;
        localEnd = start;
        break;
    }

    if (localStart!.y < 0 || localStart.y > _terminal.buffer.lines.length) {
      return List<Line>.empty();
    }

    if (localEnd!.y >= _terminal.buffer.lines.length) {
      localEnd = Point<int>(localEnd.x, _terminal.buffer.lines.length - 1);
    }

    return _getSelectedLines(localStart, localEnd);
  }

  List<Line> _getSelectedLines(Point<int> start, Point<int> end) {
    var lines = List<Line>.empty(growable: true);
    var buffer = _terminal.buffer;
    String str;
    Line currentLine = Line();
    lines.add(currentLine);

    // keep a list of blank lines that we see. if we see content after a group
    // of blanks, add those blanks but skip all remaining / trailing blanks
    // these will be blank lines in the selected text output
    var blanks = List<LineFragment>.empty(growable: true);

    Function() addBlanks = () {
      int lastLine = -1;
      for (var b in blanks) {
        if (lastLine != -1 && b.line != lastLine) {
          currentLine = new Line();
          lines.add(currentLine);
        }

        lastLine = b.line;
        currentLine.add(b);
      }
      blanks.clear();
    };

    // get the first line
    BufferLine? bufferLine = buffer.lines[start.y];
    if (bufferLine?.hasAnyContent ?? false) {
      str = _translateBufferLineToString(
          buffer, start.y, start.x, start.y < end.y ? -1 : end.x);

      var fragment = LineFragment(str, start.y, start.x);
      currentLine.add(fragment);
    }

    // get the middle rows
    var line = start.y + 1;
    var isWrapped = false;
    while (line < end.y) {
      bufferLine = buffer.lines[line];
      isWrapped = bufferLine?.isWrapped ?? false;

      str = _translateBufferLineToString(buffer, line, 0, -1);

      if (bufferLine?.hasAnyContent ?? false) {
        // add previously gathered blank fragments
        addBlanks();

        if (!isWrapped) {
          // this line is not a wrapped line, so the
          // prior line has a hard linefeed
          // add a fragment to that line
          currentLine.add(LineFragment.newLine(line - 1));

          // start a new line
          currentLine = Line();
          lines.add(currentLine);
        }

        // add the text we found to the current line
        currentLine.add(LineFragment(str, line, 0));
      } else {
        // this line has no content, which means that it's a blank line inserted
        // somehow, or one of the trailing blank lines after the last actual content
        // make a note of the line
        // check that this line is a wrapped line, if so, add a line feed fragment
        if (!isWrapped) {
          blanks.add(LineFragment.newLine(line - 1));
        }

        blanks.add(new LineFragment(str, line, 0));
      }

      line++;
    }

    // get the last row
    if (end.y != start.y) {
      bufferLine = buffer.lines[end.y];
      if (bufferLine?.hasAnyContent ?? false) {
        addBlanks();

        isWrapped = bufferLine?.isWrapped ?? false;
        str = _translateBufferLineToString(buffer, end.y, 0, end.x);
        if (!isWrapped) {
          currentLine.add(LineFragment.newLine(line - 1));
          currentLine = Line();
          lines.add(currentLine);
        }

        currentLine.add(LineFragment(str, line, 0));
      }
    }

    return lines;
  }

  String _translateBufferLineToString(
      Buffer buffer, int line, int start, int end) {
    return buffer
        .translateBuffer(line, true, start, end)
        .replaceAll(CharData.nul.rune, CharData.whiteSpace.rune);
  }

  void _simpleScanSelection(
      int col, int row, bool Function(CharData) includeFunc) {
    var buffer = _terminal.buffer;

    // Look backward
    var colScan = col;
    var left = colScan;
    while (colScan >= 0) {
      var ch = buffer.getChar(colScan, row);
      if (!includeFunc(ch)) {
        break;
      }

      left = colScan;
      colScan -= 1;
    }

    // Look forward
    colScan = col;
    var right = colScan;
    var limit = _terminal.cols;
    while (colScan < limit) {
      var ch = buffer.getChar(colScan, row);

      if (!includeFunc(ch)) {
        break;
      }

      colScan += 1;
      right = colScan;
    }

    _start = new Point(left, row);
    _end = new Point(right, row);
  }

  /// <summary>
  /// Performs a forward search for the `end` character, but this can extend across matching subexpressions
  /// made of pairs of parenthesis, braces and brackets.
  /// </summary>
  void _balancedSearchForward(int col, int row) {
    var buffer = _terminal.buffer;
    var startCol = col;
    var wait = List<CharData>.empty(growable: true);

    _start = new Point(col, row);

    for (int line = row; line < _terminal.rows; line++) {
      for (int colIndex = startCol; colIndex < _terminal.cols; colIndex++) {
        var p = Point<int>(colIndex, line);
        var ch = buffer.getChar(colIndex, line);

        if (ch.matchesRuneOfCharData(CharData.leftParenthesis)) {
          wait.insert(0, CharData.rightParenthesis);
        } else if (ch.matchesRuneOfCharData(CharData.leftBracket)) {
          wait.insert(0, CharData.rightBracket);
        } else if (ch.matchesRuneOfCharData(CharData.leftBrace)) {
          wait.insert(0, CharData.rightBrace);
        } else {
          var v = wait.length > 0 ? wait[0] : CharData.nul;
          if (!v.matchesRuneOfCharData(CharData.nul) &&
              v.matchesRuneOfCharData(ch)) {
            wait.removeAt(0);
            if (wait.length == 0) {
              _end = Point(p.x + 1, p.y);
              return;
            }
          }
        }
      }

      startCol = 0;
    }

    _start = _end = Point(col, row);
  }

  /// <summary>
  /// Performs a backward search for the `end` character, but this can extend across matching subexpressions
  /// made of pairs of parenthesis, braces and brackets.
  /// </summary>
  void _balancedSearchBackward(int col, int row) {
    var buffer = _terminal.buffer;
    var startCol = col;
    var wait = List<CharData>.empty(growable: true);

    _end = Point(col, row);

    for (int line = row; line > 0; line--) {
      for (int colIndex = startCol; colIndex > 0; colIndex--) {
        var p = Point<int>(colIndex, line);
        var ch = buffer.getChar(colIndex, line);

        if (ch.matchesRuneOfCharData(CharData.rightParenthesis)) {
          wait.insert(0, CharData.leftParenthesis);
        } else if (ch.matchesRuneOfCharData(CharData.rightBracket)) {
          wait.insert(0, CharData.leftBracket);
        } else if (ch.matchesRuneOfCharData(CharData.rightBrace)) {
          wait.insert(0, CharData.leftBrace);
        } else {
          var v = wait.length > 0 ? wait[0] : CharData.nul;
          if (!v.matchesRuneOfCharData(CharData.nul) &&
              v.matchesRuneOfCharData(ch)) {
            wait.removeAt(0);
            if (wait.length == 0) {
              _end = Point(_end!.x + 1, _end!.y);
              _start = p;
              return;
            }
          }
        }
      }

      startCol = _terminal.cols - 1;
    }

    _start = _end = Point(col, row);
  }

  static int _comparePoints(Point? a, Point? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    if (a.x < b.y) return -1;
    if (a.y > b.y) return 1;
    // x and y are on the same row, compare columns
    if (a.x < b.x) return -1;
    if (a.x > b.x) return 1;
    // they are the same
    return 0;
  }
}
