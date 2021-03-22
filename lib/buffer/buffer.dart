import 'dart:math' show max, min;

import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/cell.dart';
import 'package:xterm/buffer/cell_attr.dart';
import 'package:xterm/terminal/charset.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/utli/scroll_range.dart';
import 'package:xterm/utli/unicode_v11.dart';

import 'buffer_reflow.dart';

class Buffer {
  Buffer(this.terminal) {
    resetVerticalMargins();
    lines = List.generate(terminal.viewHeight, (_) => BufferLine());
  }

  final Terminal terminal;
  final charset = Charset();

  /// lines of the buffer. the length of [lines] should always be equal or
  /// greater than [Terminal.viewHeight].
  late final List<BufferLine> lines;

  int? _savedCursorX;
  int? _savedCursorY;
  CellAttr? _savedCellAttr;

  // Indicates how far the bottom of the viewport is from the bottom of the
  // entire buffer. 0 if the viewport overlaps the terminal screen.
  int get scrollOffsetFromBottom => _scrollOffsetFromBottom;
  int _scrollOffsetFromBottom = 0;

  // Indicates how far the top of the viewport is from the top of the entire
  // buffer. 0 if the viewport is scrolled to the top.
  int get scrollOffsetFromTop {
    return terminal.invisibleHeight - scrollOffsetFromBottom;
  }

  /// Indicated whether the terminal should automatically scroll to bottom when
  /// new lines are added. When user is scrolling, [isUserScrolling] is true and
  /// the automatical scroll-to-bottom behavior is disabled.
  bool get isUserScrolling {
    return _scrollOffsetFromBottom != 0;
  }

  /// Horizontal position of the cursor relative to the top-left cornor of the
  /// screen, starting from 0.
  int get cursorX => _cursorX.clamp(0, terminal.viewWidth - 1);
  int _cursorX = 0;

  /// Vertical position of the cursor relative to the top-left cornor of the
  /// screen, starting from 0.
  int get cursorY => _cursorY;
  int _cursorY = 0;

  int get marginTop => _marginTop;
  late int _marginTop;

  int get marginBottom => _marginBottom;
  late int _marginBottom;

  /// Writes data to the terminal. Terminal sequences or special characters are
  /// not interpreted and directly added to the buffer.
  ///
  /// See also: [Terminal.write]
  void write(String text) {
    for (var char in text.runes) {
      writeChar(char);
    }
  }

  /// Writes a single character to the terminal. Special chatacters are not
  /// interpreted and directly added to the buffer.
  ///
  /// See also: [Terminal.writeChar]
  void writeChar(int codePoint) {
    codePoint = charset.translate(codePoint);

    final cellWidth = unicodeV11.wcwidth(codePoint);
    if (_cursorX >= terminal.viewWidth) {
      newLine();
      setCursorX(0);
    }

    final line = currentLine;
    while (line.length <= _cursorX) {
      line.add(Cell());
    }

    final cell = line.getCell(_cursorX);
    cell.setCodePoint(codePoint);
    cell.setWidth(cellWidth);
    cell.setAttr(terminal.cellAttr.value);

    if (_cursorX < terminal.viewWidth) {
      _cursorX++;
    }

    if (cellWidth == 2) {
      writeChar(0);
    }
  }

  BufferLine getViewLine(int index) {
    if (index > terminal.viewHeight) {
      return lines.last;
    }

    final rawIndex = convertViewLineToRawLine(index);

    if (rawIndex >= lines.length) {
      return BufferLine();
    }

    return lines[rawIndex];
  }

  BufferLine get currentLine {
    return getViewLine(_cursorY);
  }

  int get height {
    return lines.length;
  }

  int convertViewLineToRawLine(int viewLine) {
    if (terminal.viewHeight > height) {
      return viewLine;
    }

    return viewLine + (height - terminal.viewHeight);
  }

  int convertRawLineToViewLine(int rawLine) {
    if (terminal.viewHeight > height) {
      return rawLine;
    }

    return rawLine - (height - terminal.viewHeight);
  }

  void newLine() {
    if (terminal.newLineMode) {
      setCursorX(0);
    }

    index();
  }

  void carriageReturn() {
    setCursorX(0);
  }

  void backspace() {
    if (_cursorX == 0 && currentLine.isWrapped) {
      movePosition(terminal.viewWidth - 1, -1);
    } else if (_cursorX == terminal.viewWidth) {
      movePosition(-2, 0);
    } else {
      movePosition(-1, 0);
    }
  }

  List<BufferLine> getVisibleLines() {
    if (height < terminal.viewHeight) {
      return lines.toList();
    }

    final result = <BufferLine>[];

    for (var i = height - terminal.viewHeight; i < height; i++) {
      final y = i - scrollOffsetFromBottom;
      if (y >= 0 && y < height) {
        result.add(lines[y]);
      }
    }

    return result;
  }

  void eraseDisplayFromCursor() {
    eraseLineFromCursor();

    for (var i = _cursorY + 1; i < terminal.viewHeight; i++) {
      getViewLine(i)
          .erase(terminal.cellAttr.value, 0, terminal.viewWidth, true);
    }
  }

  void eraseDisplayToCursor() {
    eraseLineToCursor();

    for (var i = 0; i < _cursorY; i++) {
      getViewLine(i)
          .erase(terminal.cellAttr.value, 0, terminal.viewWidth, true);
    }
  }

  void eraseDisplay() {
    for (var i = 0; i < terminal.viewHeight; i++) {
      final line = getViewLine(i);
      line.erase(terminal.cellAttr.value, 0, terminal.viewWidth, true);
    }
  }

  void eraseLineFromCursor() {
    currentLine.erase(
        terminal.cellAttr.value, _cursorX, terminal.viewWidth, _cursorX == 0);
  }

  void eraseLineToCursor() {
    currentLine.erase(terminal.cellAttr.value, 0, _cursorX, _cursorX == 0);
  }

  void eraseLine() {
    currentLine.erase(terminal.cellAttr.value, 0, terminal.viewWidth, true);
  }

  void eraseCharacters(int count) {
    final start = _cursorX;
    for (var i = start; i < start + count; i++) {
      if (i >= currentLine.length) {
        currentLine.add(Cell(attr: terminal.cellAttr.value));
      } else {
        currentLine.getCell(i).erase(terminal.cellAttr.value);
      }
    }
  }

  ScrollRange getAreaScrollRange() {
    var top = convertViewLineToRawLine(_marginTop);
    var bottom = convertViewLineToRawLine(_marginBottom) + 1;
    if (bottom > lines.length) {
      bottom = lines.length;
    }
    return ScrollRange(top, bottom);
  }

  void areaScrollDown(int lines) {
    final scrollRange = getAreaScrollRange();

    for (var i = scrollRange.bottom; i > scrollRange.top;) {
      i--;
      if (i >= scrollRange.top + lines) {
        this.lines[i] = this.lines[i - lines];
      } else {
        this.lines[i] = BufferLine();
      }
    }
  }

  void areaScrollUp(int lines) {
    final scrollRange = getAreaScrollRange();

    for (var i = scrollRange.top; i < scrollRange.bottom; i++) {
      if (i + lines < scrollRange.bottom) {
        this.lines[i] = this.lines[i + lines];
      } else {
        this.lines[i] = BufferLine();
      }
    }
  }

  /// https://vt100.net/docs/vt100-ug/chapter3.html#IND IND – Index
  ///
  /// ESC D
  ///
  /// [index] causes the active position to move downward one line without
  /// changing the column position. If the active position is at the bottom
  /// margin, a scroll up is performed.
  void index() {
    if (isInScrollableRegion) {
      if (_cursorY < _marginBottom) {
        moveCursorY(1);
      } else {
        areaScrollUp(1);
      }
      return;
    }

    // the cursor is not in the scrollable region
    if (_cursorY >= terminal.viewHeight - 1) {
      // we are at the bottom so a new line is created.
      lines.add(BufferLine());

      // keep viewport from moving if user is scrolling.
      if (isUserScrolling) {
        _scrollOffsetFromBottom++;
      }

      // clean extra lines if needed.
      trimLines();
    } else {
      // there're still lines so we simply move cursor down.
      moveCursorY(1);
    }
  }

  /// https://vt100.net/docs/vt100-ug/chapter3.html#RI
  void reverseIndex() {
    if (_cursorY == _marginTop) {
      areaScrollDown(1);
    } else if (_cursorY > 0) {
      moveCursorY(-1);
    }
  }

  Cell? getCell(int col, int row) {
    final rawRow = convertViewLineToRawLine(row);
    return getRawCell(col, rawRow);
  }

  Cell? getRawCell(int col, int rawRow) {
    if (col < 0 || rawRow < 0 || rawRow >= lines.length) {
      return null;
    }

    final line = lines[rawRow];
    if (col >= line.length) {
      return null;
    }

    return line.getCell(col);
  }

  Cell? getCellUnderCursor() {
    return getCell(cursorX, cursorY);
  }

  void cursorGoForward() {
    setCursorX(_cursorX + 1);
  }

  void setCursorX(int cursorX) {
    _cursorX = cursorX.clamp(0, terminal.viewWidth - 1);
  }

  void setCursorY(int cursorY) {
    _cursorY = cursorY.clamp(0, terminal.viewHeight - 1);
  }

  void moveCursorX(int offset) {
    setCursorX(_cursorX + offset);
  }

  void moveCursorY(int offset) {
    setCursorY(_cursorY + offset);
  }

  void setPosition(int cursorX, int cursorY) {
    var maxLine = terminal.viewHeight - 1;

    if (terminal.originMode) {
      cursorY += _marginTop;
      maxLine = _marginBottom;
    }

    _cursorX = cursorX.clamp(0, terminal.viewWidth - 1);
    _cursorY = cursorY.clamp(0, maxLine);
  }

  void movePosition(int offsetX, int offsetY) {
    final cursorX = _cursorX + offsetX;
    final cursorY = _cursorY + offsetY;
    setPosition(cursorX, cursorY);
  }

  void setScrollOffsetFromBottom(int offsetFromBottom) {
    if (height < terminal.viewHeight) return;
    final maxOffsetFromBottom = height - terminal.viewHeight;
    _scrollOffsetFromBottom = offsetFromBottom.clamp(0, maxOffsetFromBottom);
  }

  void setScrollOffsetFromTop(int offsetFromTop) {
    final bottomOffset = terminal.invisibleHeight - offsetFromTop;
    setScrollOffsetFromBottom(bottomOffset);
  }

  void screenScrollUp(int lines) {
    setScrollOffsetFromBottom(scrollOffsetFromBottom + lines);
  }

  void screenScrollDown(int lines) {
    setScrollOffsetFromBottom(scrollOffsetFromBottom - lines);
  }

  void saveCursor() {
    _savedCellAttr = terminal.cellAttr.value;
    _savedCursorX = _cursorX;
    _savedCursorY = _cursorY;
    charset.save();
  }

  void adjustSavedCursor(int diffX, int diffY) {
    if (_savedCursorX != null) {
      _savedCursorX = _savedCursorX! + diffX;
    }
    if (_savedCursorY != null) {
      _savedCursorY = _savedCursorY! + diffY;
    }
  }

  void restoreCursor() {
    if (_savedCellAttr != null) {
      terminal.cellAttr.use(_savedCellAttr!);
    }

    if (_savedCursorX != null) {
      _cursorX = _savedCursorX!;
    }

    if (_savedCursorY != null) {
      _cursorY = _savedCursorY!;
    }

    charset.restore();
  }

  void setVerticalMargins(int top, int bottom) {
    _marginTop = top.clamp(0, terminal.viewHeight - 1);
    _marginBottom = bottom.clamp(0, terminal.viewHeight - 1);

    _marginTop = min(_marginTop, _marginBottom);
    _marginBottom = max(_marginTop, _marginBottom);
  }

  bool get hasScrollableRegion {
    return _marginTop > 0 || _marginBottom < (terminal.viewHeight - 1);
  }

  bool get isInScrollableRegion {
    return hasScrollableRegion &&
        _cursorY >= _marginTop &&
        _cursorY <= _marginBottom;
  }

  void resetVerticalMargins() {
    setVerticalMargins(0, terminal.viewHeight - 1);
  }

  void deleteChars(int count) {
    final start = _cursorX.clamp(0, currentLine.length);
    final end = min(_cursorX + count, currentLine.length);
    currentLine.removeRange(start, end);
  }

  void clearScrollback() {
    if (lines.length <= terminal.viewHeight) {
      return;
    }

    lines.removeRange(0, lines.length - terminal.viewHeight);
  }

  void clear() {
    lines.clear();
    lines.addAll(List.generate(terminal.viewHeight, (_) => BufferLine()));
  }

  void insertBlankCharacters(int count) {
    for (var i = 0; i < count; i++) {
      final cell = Cell(attr: terminal.cellAttr.value);
      currentLine.insert(_cursorX + i, cell);
    }
  }

  void insertLines(int count) {
    if (hasScrollableRegion && !isInScrollableRegion) {
      return;
    }

    setCursorX(0);

    for (var i = 0; i < count; i++) {
      insertLine();
    }
  }

  void insertLine() {
    if (!isInScrollableRegion) {
      final index = convertViewLineToRawLine(_cursorX);
      final newLine = BufferLine();
      lines.insert(index, newLine);

      final maxLines = terminal.maxLines;
      if (maxLines != null && lines.length > maxLines) {
        lines.removeRange(0, lines.length - maxLines);
      }
    } else {
      final bottom = convertViewLineToRawLine(marginBottom);

      final movedLines = lines.getRange(_cursorY, bottom - 1);
      lines.setRange(_cursorY + 1, bottom, movedLines);

      final newLine = BufferLine();
      lines[_cursorY] = newLine;
    }
  }

  void deleteLines(int count) {
    if (hasScrollableRegion && !isInScrollableRegion) {
      return;
    }

    setCursorX(0);

    for (var i = 0; i < count; i++) {
      deleteLine();
    }
  }

  void deleteLine() {
    final index = convertViewLineToRawLine(_cursorX);

    if (index >= height) {
      return;
    }

    lines.removeAt(index);
  }

  void trimLines() {
    final maxLines = terminal.maxLines;
    if (maxLines != null && lines.length > maxLines) {
      lines.removeRange(0, lines.length - maxLines);
    }
  }

  void resize(
      int width, int height, int oldWidth, int oldHeight, bool doReflow) {
    if (this.lines.length > 0) {
      if (oldHeight < height) {
        for (int y = oldHeight; y < height; y++) {
          if (_cursorY < terminal.viewHeight - 1) {
            lines.add(BufferLine());
          } else {
            _cursorY++;
          }
        }
      } else {
        for (var i = 0; i < oldHeight - height; i++) {
          if (_cursorY < terminal.viewHeight - 1) {
            lines.removeLast();
          } else {
            _cursorY++;
          }
        }
      }
    }

    // ScrollBottom = newRows - 1;

    if (doReflow) {
      final rf = BufferReflow(this);
      rf.doReflow(oldWidth, width);
      trimLines();
    }
  }
}
