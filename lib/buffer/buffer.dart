import 'dart:math';

import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/char_data.dart';
import 'package:xterm/buffer/reflow_strategy.dart';
import 'package:xterm/buffer/reflow_strategy_narrower.dart';
import 'package:xterm/buffer/reflow_strategy_wider.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/util/bit_array.dart';
import 'package:xterm/util/circular_list.dart';

class Buffer {
  late CircularList<BufferLine> _lines;
  int _scrollTop;
  int _scrollBottom;
  int yDisp;
  int yBase;
  int x;
  int _y;
  int savedX = 0;
  int savedY = 0;
  int savedAttr = CharData.DefaultAttr;
  BitArray _tabStops = BitArray(0);

  Terminal _terminal;
  bool _hasScrollback;

  int _rows;
  int _cols;

  int _marginLeft;
  int _marginRight;

  Buffer(this._terminal, {hasScrollback = true})
      : _hasScrollback = hasScrollback,
        _rows = _terminal.rows,
        _cols = _terminal.cols,
        _marginLeft = 0,
        _marginRight = _terminal.cols - 1,
        _scrollTop = 0,
        _scrollBottom = _terminal.rows - 1,
        yDisp = 0,
        yBase = 0,
        x = 0,
        _y = 0 {
    _lines = CircularList<BufferLine>(_getCorrectBufferLength(
        _rows, _hasScrollback, _terminal.options.scrollback));
  }

  static int _getCorrectBufferLength(
      int rows, bool hasScrollback, int? scrollback) {
    if (!hasScrollback) {
      return rows;
    }
    return rows + (scrollback ?? 0);
  }

  int get cols => _cols;
  int get rows => _rows;

  /// Gets the top scrolling region in the buffer when Origin Mode is turned on
  int get scrollTop => _scrollTop;

  /// Sets the top scrolling region in the buffer when Origin Mode is turned on
  set scrollTop(int value) {
    if (value >= 0) {
      _scrollTop = value;
    }
  }

  /// Gets the top scrolling region in the buffer when Origin Mode is turned on
  int get scrollBottom => _scrollBottom;

  /// Sets the top scrolling region in the buffer when Origin Mode is turned on
  set scrollBottom(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'scrollBottom',
          'value for scrollBottom has to be greater than 0!');
    }
  }

  /// Gets the left margin, 0 based
  int get marginLeft => _marginLeft;

  /// Gets the right margin, 0 based
  int get marginRight => _marginRight;

  int get y => _y;

  set y(int value) {
    if (value < 0 || value > _terminal.rows - 1) {
      print(
          'Terminal Buffer error: Y cannot be outside the bounds of the terminal rows. Y: ${_y}, Rows: ${_terminal.rows}');
    } else {
      _y = value;
    }
  }

  Terminal get terminal => _terminal;

  /// Gets a value indicating whether this <see cref="T:XtermSharp.Buffer"/> has scrollback.
  bool get hasScrollback => _hasScrollback && _lines.maxLength > _terminal.rows;

  CircularList<BufferLine> get lines => _lines;

  /// Returns the CharData at the specified position in the buffer
  CharData getChar(int col, int row) {
    var bufferRow = _lines[row];
    if (bufferRow == null) {
      return CharData.nul;
    }

    if (col >= bufferRow.length || col < 0) {
      return CharData.nul;
    }

    return bufferRow[col];
  }

  BufferLine getBlankLine(int attribute, [bool isWrapped = false]) {
    return BufferLine(_terminal.cols, CharData(attribute));
  }

  void clear() {
    yDisp = 0;
    yBase = 0;
    x = 0;
    _y = 0;
    _lines = CircularList<BufferLine>(_getCorrectBufferLength(
        _terminal.rows, _hasScrollback, _terminal.options.scrollback));
    _scrollTop = 0;
    _scrollBottom = _terminal.rows - 1;
    setupTabStops();
  }

  bool get isCursorInViewPort {
    final absoluteY = yBase + y;
    final relativeY = absoluteY - yDisp;
    return (relativeY >= 0 && relativeY < _terminal.rows);
  }

  void setMargins(int left, int right) {
    left = min(left, right);
    _marginLeft = left;
    _marginRight = right;
  }

  void saveCursor(int curAttr) {
    savedX = x;
    savedY = _y;
    savedAttr = curAttr;
  }

  int restoreCursor() {
    x = savedX;
    _y = savedY;
    return savedAttr;
  }

  void fillViewportRows([int? attribute = null]) {
    // TODO: limitation in original, this does not cope with partial fills, it is either zero or nothing
    if (_lines.length != 0) {
      return;
    }
    final attr = attribute ?? CharData.DefaultAttr;
    for (int i = _terminal.rows; i > 0; i--) {
      _lines.push(getBlankLine(attr));
    }
  }

  bool get isReflowEnabled => _hasScrollback;

  void resize(int newCols, int newRows) {
    var newMaxLength = _getCorrectBufferLength(
        newRows, _hasScrollback, _terminal.options.scrollback);
    if (newMaxLength > _lines.maxLength) {
      _lines.maxLength = newMaxLength;
    }

    if (this._lines.length > 0) {
      // Deal with columns increasing (reducing needs to happen after reflow)
      if (cols < newCols) {
        for (int i = 0; i < _lines.maxLength; i++) {
          _lines[i]?.resize(newCols, CharData.nul);
        }
      }

      // Resize rows in both directions as needed
      int addToY = 0;
      if (_rows < newRows) {
        for (int y = _rows; y < newRows; y++) {
          if (_lines.length < newRows + yBase) {
            if (yBase > 0 && _lines.length <= yBase + _y + addToY + 1) {
              // There is room above the buffer and there are no empty elements below the line,
              // scroll up
              yBase--;
              addToY++;
              if (yDisp > 0) {
                // Viewport is at the top of the buffer, must increase downwards
                yDisp--;
              }
            } else {
              // Add a blank line if there is no buffer left at the top to scroll to, or if there
              // are blank lines after the cursor
              _lines.push(BufferLine(newCols, CharData.nul));
            }
          }
        }
      } else {
        for (int y = _rows; y > newRows; y--) {
          if (_lines.length > newRows + yBase) {
            if (_lines.length > yBase + _y + 1) {
              // The line is a blank line below the cursor, remove it
              _lines.pop();
            } else {
              // The line is the cursor, scroll down
              yBase++;
              yDisp++;
            }
          }
        }
      }

      // Reduce max length if needed after adjustments, this is done after as it
      // would otherwise cut data from the bottom of the buffer.
      if (newMaxLength < _lines.maxLength) {
        // Trim from the top of the buffer and adjust ybase and ydisp.
        int amountToTrim = _lines.length - newMaxLength;
        if (amountToTrim > 0) {
          _lines.trimStart(amountToTrim);
          yBase = max(yBase - amountToTrim, 0);
          yDisp = max(yDisp - amountToTrim, 0);
          savedY = max(savedY - amountToTrim, 0);
        }

        _lines.maxLength = newMaxLength;
      }

      // Make sure that the cursor stays on screen
      x = min(x, newCols - 1);
      y = min(y, newRows - 1);
      if (addToY != 0) {
        y += addToY;
      }

      savedX = min(savedX, newCols - 1);

      _scrollTop = 0;
    }

    _scrollBottom = newRows - 1;

    if (isReflowEnabled) {
      this.reflow(newCols, newRows);

      // Trim the end of the line off if cols shrunk
      if (cols > newCols) {
        for (int i = 0; i < _lines.maxLength; i++) {
          _lines[i]?.resize(newCols, CharData.nul);
        }
      }
    }

    _rows = newRows;
    _cols = newCols;
    if (_marginRight > newCols - 1) {
      _marginRight = newCols - 1;
    }
    if (_marginLeft > _marginRight) {
      _marginLeft = _marginRight;
    }
  }

  String translateBuffer(int lineIndex, bool trimRight,
      [int startCol = 0, int endCol = -1]) {
    try {
      return _lines[lineIndex]!.translateToString(trimRight, startCol, endCol);
    } catch (ex) {
      return '';
    }
  }

  void setupTabStops([int index = -1]) {
    if (index != -1) {
      _tabStops.length = cols;

      final from = min(index, cols - 1);
      if (!_tabStops[from]) {
        index = previousTabStop(from);
      }
    } else {
      _tabStops = BitArray(cols);
      index = 0;
    }

    int tabStopWidth = _terminal.options.tabStopWidth;
    for (int i = index; i < cols; i += tabStopWidth) {
      _tabStops[i] = true;
    }
  }

  void tabSet(int pos) {
    if (pos < _tabStops.length) {
      _tabStops[pos] = true;
    }
  }

  void clearStop(int pos) {
    if (pos < _tabStops.length) {
      _tabStops[pos] = false;
    }
  }

  void clearTabStops() {
    _tabStops = BitArray(_tabStops.length);
  }

  int previousTabStop([int index = -1]) {
    if (index == -1) {
      index = x;
    }
    while (index > 0 && !_tabStops[index]) {
      index--;
    }
    return index >= _cols ? _cols - 1 : index;
  }

  int nextTabStop([int index = -1]) {
    final limit = _terminal.marginMode ? _marginRight : (_cols - 1);
    if (index == -1) {
      index = x;
    }

    do {
      index++;
      if (index > limit) {
        break;
      }
      if (_tabStops[index]) {
        break;
      }
    } while (index < limit);

    return index >= limit ? limit : index;
  }

  void reflow(int newCols, int newRows) {
    if (cols == newCols) {
      return;
    }

    // Iterate through rows, ignore the last one as it cannot be wrapped
    ReflowStrategy strategy = (newCols > cols)
        ? ReflowStrategyWider(this)
        : ReflowStrategyNarrower(this);

    strategy.reflow(newCols, newRows, cols, rows);
  }
}
