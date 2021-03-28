import 'dart:convert';
import 'dart:core';
import 'dart:math';
import 'dart:typed_data';

import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/buffer_set.dart';
import 'package:xterm/buffer/char_data.dart';
import 'package:xterm/input/input_handler.dart';
import 'package:xterm/input/mouse_mode.dart';
import 'package:xterm/input/mouse_protocol_encoding.dart';
import 'package:xterm/terminal/char_sets.dart';
import 'package:xterm/terminal/control_codes.dart';
import 'package:xterm/terminal/terminal_delegate.dart';
import 'package:xterm/terminal/terminal_options.dart';

class Terminal {
  static const int MINIMUM_COLS = 2;
  static const int MINIMUM_ROWS = 1;

  final TerminalDelegate _terminalDelegate;
  final ControlCodes _controlCodes;
  final List<String> _titleStack;
  final List<String> _iconTitleStack;
  late final BufferSet _buffers;
  late final InputHandler _input;
  final TerminalOptions _options;
  final _utf8Encoder = Utf8Encoder();

  BufferLine? _blankLine;

  // saved modes
  bool _savedMarginMode = false;
  bool _savedOriginMode = false;
  bool _savedWraparound = false;
  bool _savedReverseWraparound = false;

  // unsorted
  int _gcharset = 0;
  int _gLevel = 0;
  int? _refreshStart;
  int? _refreshEnd;
  bool _userScrolling = false;

  Terminal([TerminalDelegate? terminalDelegate, TerminalOptions? options])
      : _terminalDelegate = terminalDelegate ?? DummyTerminalDelegate(),
        _options = options ?? TerminalOptions(),
        _controlCodes = ControlCodes(false),
        _titleStack = List<String>.empty(growable: true),
        _iconTitleStack = List<String>.empty(growable: true) {
    _input = InputHandler(this);
    _cols = max(_options.cols, MINIMUM_COLS);
    _rows = max(_options.rows, MINIMUM_ROWS);
    _buffers = BufferSet(this);
    setup();
  }

  TerminalDelegate get delegate => _terminalDelegate;
  ControlCodes get controlCodes => _controlCodes;

  String _title = '';
  String get title => _title;

  String _iconTitle = '';
  String get iconTitle => _iconTitle;

  Buffer get buffer => _buffers.active;
  BufferSet get buffers => _buffers;

  bool marginMode = false;
  bool originMode = false;
  bool wraparound = false;
  bool reverseWraparound = false;
  MouseMode mouseMode = MouseMode.Off;

  MouseProtocolEncoding mouseProtocol = MouseProtocolEncoding.UTF8;

  bool allow80To132 = false;

  Map<int, String>? charset;

  bool applicationCursor = false;

  int _savedCols = 0;
  int get savedCols => _savedCols;

  bool applicationKeypad = false;
  bool sendFocus = false;
  bool cursorHidden = false;
  bool bracketedPasteMode = false;

  TerminalOptions get options => _options;

  int _cols = 0;
  int get cols => _cols;

  int _rows = 0;
  int get rows => _rows;

  bool insertMode = false;

  int curAttr = 0;

  //Input handler API
  setTitle(String title) {
    _title = title;
    _terminalDelegate.setTerminalTitle(this, title);
  }

  pushTitle() {
    _titleStack.insert(0, title);
  }

  popTitle() {
    if (_titleStack.length > 0) {
      setTitle(_titleStack[0]);
      _titleStack.removeAt(0);
    }
  }

  setIconTitle(String iconTitle) {
    _iconTitle = _iconTitle;
    _terminalDelegate.setTerminalIconTitle(this, iconTitle);
  }

  void pushIconTitle() {
    _iconTitleStack.insert(0, iconTitle);
  }

  void popIconTitle() {
    if (_iconTitleStack.length > 0) {
      setIconTitle(_iconTitleStack[0]);
      _iconTitleStack.removeAt(0);
    }
  }

  sendResponse(String txt) {
    _terminalDelegate.send(_utf8Encoder.convert(txt));
  }

  sendResponseMultiple(List<Object> objs) {
    List<Uint8List> _dataToSend = List<Uint8List>.empty(growable: true);
    for (final o in objs) {
      if (o is String) {
        _dataToSend.add(_utf8Encoder.convert(o));
      } else if (o is Uint8List) {
        _dataToSend.add(o);
      } else if (o is int) {
        _dataToSend.add(Uint8List.fromList([o]));
      }
    }
    final count = _dataToSend.fold(
        0, (int previousValue, element) => previousValue + element.length);
    final result = Uint8List(count);
    int idx = 0;
    for (final l in _dataToSend) {
      for (final b in l) {
        result[idx] = b;
        idx++;
      }
    }
    _terminalDelegate.send(result);
  }

  void error(String message, [List<Object?>? params]) {
    report('ERROR', message, params);
  }

  void log(String message, [List<Object?>? params]) {
    report('LOG', message, params);
  }

  void feedData(Uint8List data) {
    _input.parse(data);
  }

  void feedString(String string) {
    _input.parse(_utf8Encoder.convert(string));
  }

  void updateRange(int y) {
    if (y < 0) {
      throw ArgumentError.value(y, 'y');
    }

    if (_refreshStart == null || y < _refreshStart!) {
      _refreshStart = y;
    }
    if (_refreshEnd == null || y > _refreshEnd!) {
      _refreshEnd = y;
    }
  }

  UpdateRange? getUpdateRange() {
    if (_refreshStart == null || _refreshEnd == null) {
      return null;
    }
    return UpdateRange(_refreshStart!, _refreshEnd!);
  }

  clearUpdateRange() {
    _refreshStart = null;
    _refreshEnd = null;
  }

  emitChar(int ch) {
    // For accessibility purposes 'a11y.char' in the original source.
  }

  //
  // ESC c Full Reset (RIS)
  //
  void reset() {
    _options.rows = rows;
    _options.cols = cols;

    var savedCursorHidden = cursorHidden;
    setup();
    cursorHidden = savedCursorHidden;
    refresh(0, rows - 1);
    syncScrollArea();
  }

  //
  // ESC D Index (Index is 0x84)
  //
  void index() {
    var buffer = this.buffer;
    var newY = buffer.y + 1;
    if (newY > buffer.scrollBottom) {
      scroll();
    } else {
      buffer.y = newY;
    }
    // If the end of the line is hit, prevent this action from wrapping around to the next line.
    if (buffer.x > cols) {
      buffer.x--;
    }
  }

  void scroll([bool isWrapped = false]) {
    var buffer = this.buffer;
    var newLine = _blankLine;
    if (newLine == null ||
        newLine.length != cols ||
        newLine[0].attribute != eraseAttr()) {
      newLine = buffer.getBlankLine(eraseAttr(), isWrapped);
      _blankLine = newLine;
    }
    newLine.isWrapped = isWrapped;

    var topRow = buffer.yBase + buffer.scrollTop;
    var bottomRow = buffer.yBase + buffer.scrollBottom;

    if (buffer.scrollTop == 0) {
      // Determine whether the buffer is going to be trimmed after insertion.
      var willBufferBeTrimmed = buffer.lines.isFull;

      // Insert the line using the fastest method
      if (bottomRow == buffer.lines.length - 1) {
        if (willBufferBeTrimmed) {
          buffer.lines.recycle()!.copyFrom(newLine);
        } else {
          buffer.lines.push(BufferLine.createFrom(newLine));
        }
      } else {
        buffer.lines.splice(bottomRow + 1, 0, [BufferLine.createFrom(newLine)]);
      }

      // Only adjust ybase and ydisp when the buffer is not trimmed
      if (!willBufferBeTrimmed) {
        buffer.yBase++;
        // Only scroll the ydisp with ybase if the user has not scrolled up
        if (!_userScrolling) {
          buffer.yDisp++;
        }
      } else {
        // When the buffer is full and the user has scrolled up, keep the text
        // stable unless ydisp is right at the top
        if (_userScrolling) {
          buffer.yDisp = max(buffer.yDisp - 1, 0);
        }
      }
    } else {
      // scrollTop is non-zero which means no line will be going to the
      // scrollback, instead we can just shift them in-place.
      var scrollRegionHeight = bottomRow - topRow + 1 /*as it's zero-based*/;

      if (scrollRegionHeight > 1) {
        buffer.lines.shiftElements(topRow + 1, scrollRegionHeight - 1, -1);
      }

      buffer.lines[bottomRow] = BufferLine.createFrom(newLine);
    }

    // Move the viewport to the bottom of the buffer unless the user is
    // scrolling.
    if (!_userScrolling) {
      buffer.yDisp = buffer.yBase;
    }

    // Flag rows that need updating
    updateRange(buffer.scrollTop);
    updateRange(buffer.scrollBottom);

    /**
   * This event is emitted whenever the terminal is scrolled.
   * The one parameter passed is the new y display position.
   *
   * @event scroll
   */
    onScrolled?.call(this, buffer.yDisp);
  }

  /// <summary>
  /// Scroll the display of the terminal
  /// </summary>
  /// <param name="disp">The number of lines to scroll down (negative scroll up)</param>
  /// <param name="suppressScrollEvent">Don't emit the scroll event as scrollLines. This is use to avoid unwanted
  /// events being handled by the viewport when the event was triggered from the viewport originally.</param>
  void scrollLines(int disp, [bool suppressScrollEvent = false]) {
    if (disp < 0) {
      if (buffer.yDisp == 0) {
        return;
      }

      _userScrolling = true;
    } else if (disp + buffer.yDisp >= buffer.yBase) {
      _userScrolling = false;
    }

    int oldYdisp = buffer.yDisp;
    buffer.yDisp = max(min(buffer.yDisp + disp, buffer.yBase), 0);

    // No change occurred, don't trigger scroll/refresh
    if (oldYdisp == buffer.yDisp) {
      return;
    }

    if (!suppressScrollEvent) {
      onScrolled?.call(this, buffer.yDisp);
    }

    refresh(0, rows - 1);
  }

  Function(Terminal, int)? onScrolled;

  Function(Terminal, String)? onDataEmitted;

  bell() {
    //
  }

  emitLineFeed() {
    lineFeedEvent?.call(this);
  }

  Function(Terminal)? lineFeedEvent;

  emitA11yTab(Object p) {
    throw UnimplementedError();
  }

  setgLevel(int v) {
    _gLevel = v;
    final cs = CharSets.all[v];
    if (cs != null) {
      charset = cs;
    } else {
      charset = null;
    }
  }

  int eraseAttr() {
    return (CharData.DefaultAttr & ~0x1ff) | curAttr & 0x1ff;
  }

  emitScroll(int v) {
    //
  }

  setgCharset(int v, Map<int, String>? charset) {
    CharSets.all[v] = charset;
    if (_gLevel == v) {
      this.charset = charset;
    }
  }

  resize(int cols, int rows) {
    if (cols < MINIMUM_COLS) cols = MINIMUM_COLS;
    if (rows < MINIMUM_ROWS) rows = MINIMUM_ROWS;
    if (cols == this.cols && rows == this.rows) return;

    var oldCols = this.cols;
    _cols = cols;
    _rows = rows;
    buffers.resize(cols, rows);
    buffers.setupTabStops(oldCols);
    refresh(0, rows - 1);
  }

  syncScrollArea() {
    // This should call the viewport syncscrollarea
    //throw new NotImplementedException ();
  }

  refresh(int startRow, int endRow) {
    updateRange(startRow);
    updateRange(endRow);
  }

  showCursor() {
    if (cursorHidden == false) return;
    cursorHidden = false;
    refresh(buffer.y, buffer.y);
    _terminalDelegate.showCursor(this);
  }

  /// <summary>
  /// Encodes button and position to characters
  /// </summary>
  Uint8List encodeMouseUtf(Uint8List data, int ch) {
    final tmpData = List<int>.from(data, growable: true);
    if (ch == 2047) {
      tmpData.add(0);
      return Uint8List.fromList(tmpData);
    }
    if (ch < 127) {
      tmpData.add(ch);
    } else {
      if (ch > 2047) ch = 2047;
      tmpData.add((0xC0 | (ch >> 6)));
      tmpData.add((0x80 | (ch & 0x3F)));
    }
    return Uint8List.fromList(tmpData);
  }

  /// <summary>
  /// Encodes the mouse button.
  /// </summary>
  /// <returns>The mouse button.</returns>
  /// <param name="button">Button (0, 1, 2 for left, middle, right) and 4 for wheel up, and 5 for wheel down.</param>
  /// <param name="release">If set to <c>true</c> release.</param>
  /// <param name="wheelUp">If set to <c>true</c> wheel up.</param>
  /// <param name="shift">If set to <c>true</c> shift.</param>
  /// <param name="meta">If set to <c>true</c> meta.</param>
  /// <param name="control">If set to <c>true</c> control.</param>
  int encodeMouseButton(
      int button, bool release, bool shift, bool meta, bool control) {
    int value;

    if (release)
      value = 3;
    else {
      switch (button) {
        case 0:
          value = 0;
          break;
        case 1:
          value = 1;
          break;
        case 2:
          value = 2;
          break;
        case 4:
          value = 64;
          break;
        case 5:
          value = 65;
          break;
        default:
          value = 0;
          break;
      }
    }

    if (mouseMode.sendsModifiers) {
      if (shift) value |= 4;
      if (meta) value |= 8;
      if (control) value |= 16;
    }
    return value;
  }

  /// <summary>
  /// Sends a mouse event for a specific button at the specific location
  /// </summary>
  /// <param name="buttonFlags">Button flags encoded in Cb mode.</param>
  /// <param name="x">The x coordinate.</param>
  /// <param name="y">The y coordinate.</param>
  sendEvent(int buttonFlags, int x, int y) {
    switch (mouseProtocol) {
      case MouseProtocolEncoding.X10:
        sendResponseMultiple([
          controlCodes.csi,
          'M',
          (buttonFlags + 32),
          min(255, (32 + x + 1)),
          min(255, (32 + y + 1))
        ]);
        break;
      case MouseProtocolEncoding.SGR:
        final bflags =
            ((buttonFlags & 3) == 3) ? (buttonFlags & ~3) : buttonFlags;
        final m = ((buttonFlags & 3) == 3) ? 'm' : 'M';
        sendResponseMultiple(
            [controlCodes.csi, '<$bflags;${x + 1};${y + 1}$m']);
        break;
      case MouseProtocolEncoding.URXVT:
        sendResponseMultiple(
            [controlCodes.csi, '${buttonFlags + 32};${x + 1};${y + 1}M']);
        break;
      case MouseProtocolEncoding.UTF8:
        var utf8 = Uint8List.fromList([0x4d /* M */]);
        utf8 = encodeMouseUtf(utf8, buttonFlags + 32);
        utf8 = encodeMouseUtf(utf8, x + 33);
        utf8 = encodeMouseUtf(utf8, y + 33);
        sendResponseMultiple([controlCodes.csi, utf8]);
        break;
    }
  }

  sendMouseMotion(int buttonFlags, int x, int y) {
    sendEvent(buttonFlags + 32, x, y);
  }

  int matchColor(int r1, int g1, int b1) {
    throw UnimplementedError();
  }

  emitData(String txt) {
    onDataEmitted?.call(this, txt);
  }

  /// <summary>
  /// Implement to change the cursor style, call the base implementation.
  /// </summary>
  /// <param name="style"></param>
  setCursorStyle(CursorStyle style) {}

  reverseIndex() {
    final buffer = this.buffer;

    if (buffer.y == buffer.scrollTop) {
      // possibly move the code below to term.reverseScroll();
      // test: echo -ne '\e[1;1H\e[44m\eM\e[0m'
      // blankLine(true) is xterm/linux behavior
      var scrollRegionHeight = buffer.scrollBottom - buffer.scrollTop;
      buffer.lines
          .shiftElements(buffer.y + buffer.yBase, scrollRegionHeight, 1);
      buffer.lines[buffer.y + buffer.yBase] = buffer.getBlankLine(eraseAttr());
      updateRange(buffer.scrollTop);
      updateRange(buffer.scrollBottom);
    } else {
      buffer.y--;
    }
  }

  // Cursor commands

  setCursor(int col, int row) {
    var buffer = this.buffer;

    // make sure we stay within the boundaries
    col = min(max(col, 0), buffer.cols - 1);
    row = min(max(row, 0), buffer.rows - 1);

    if (originMode) {
      buffer.x = col + (isUsingMargins() ? buffer.marginLeft : 0);
      buffer.y = buffer.scrollTop + row;
    } else {
      buffer.x = col;
      buffer.y = row;
    }
  }

  /// <summary>
  // Moves the cursor up by rows
  /// </summary>
  cursorUp(int rows) {
    var buffer = this.buffer;
    var top = buffer.scrollTop;

    if (buffer.y < top) {
      top = 0;
    }

    if (buffer.y - rows < top)
      buffer.y = top;
    else
      buffer.y -= rows;
  }

  /// <summary>
  // Moves the cursor down by rows
  /// </summary>
  cursorDown(int rows) {
    var buffer = this.buffer;
    var bottom = buffer.scrollBottom;

    // When the cursor starts below the scroll region, CUD moves it down to the
    // bottom of the screen.
    if (buffer.y > bottom) {
      bottom = buffer.rows - 1;
    }

    var newY = buffer.y + rows;

    if (newY >= bottom)
      buffer.y = bottom;
    else
      buffer.y = newY;

    // If the end of the line is hit, prevent this action from wrapping around to the next line.
    if (buffer.x >= cols) buffer.x--;
  }

  /// <summary>
  // Moves the cursor forward by cols
  /// </summary>
  cursorForward(int cols) {
    var right = marginMode ? buffer.marginRight : buffer.cols - 1;

    if (buffer.x > right) {
      right = buffer.cols - 1;
    }

    buffer.x += cols;
    if (buffer.x > right) {
      buffer.x = right;
    }
  }

  /// <summary>
  // Moves the cursor forward by cols
  /// </summary>
  cursorBackward(int cols) {
    // What is our left margin - depending on the settings.
    var left = marginMode ? buffer.marginLeft : 0;

    // If the cursor is positioned before the margin, we can go backwards to the first column
    if (buffer.x < left) {
      left = 0;
    }
    buffer.x -= cols;

    if (buffer.x < left) {
      buffer.x = left;
    }
  }

  /// <summary>
  /// Performs a backwards tab
  /// </summary>
  cursorBackwardTab(int tabs) {
    while (tabs-- != 0) {
      buffer.x = buffer.previousTabStop();
    }
  }

  /// <summary>
  /// Moves the cursor to the given column
  /// </summary>
  void cursorCharAbsolute(int col) {
    buffer.x = (isUsingMargins() ? buffer.marginLeft : 0) +
        min(col - 1, buffer.cols - 1);
  }

  /// <summary>
  /// Performs a linefeed
  /// </summary>
  lineFeed() {
    if (options.convertEol) {
      buffer.x = marginMode ? buffer.marginLeft : 0;
    }

    lineFeedBasic();
  }

  /// <summary>
  /// Performs a basic linefeed
  /// </summary>
  lineFeedBasic() {
    var by = buffer.y;

    if (by == buffer.scrollBottom) {
      scroll(false);
    } else if (by == buffer.rows - 1) {
    } else {
      buffer.y = by + 1;
    }

    // If the end of the line is hit, prevent this action from wrapping around to the next line.
    if (buffer.x >= buffer.cols) {
      buffer.x -= 1;
    }

    // This event is emitted whenever the terminal outputs a LF or NL.
    emitLineFeed();
  }

  /// <summary>
  /// Moves cursor to first position on next line.
  /// </summary>
  nextLine() {
    buffer.x = isUsingMargins() ? buffer.marginLeft : 0;
    index();
  }

  /// <summary>
  /// Save cursor (ANSI.SYS).
  /// </summary>
  saveCursor() {
    buffer.saveCursor(curAttr);
  }

  /// <summary>
  /// Restores the cursor and modes
  /// </summary>
  restoreCursor() {
    curAttr = buffer.restoreCursor();
    marginMode = _savedMarginMode;
    originMode = _savedOriginMode;
    wraparound = _savedWraparound;
    reverseWraparound = _savedReverseWraparound;
  }

  /// <summary>
  /// Restrict cursor to viewport size / scroll margin (origin mode)
  /// - Parameter limitCols: by default it is true, but the reverseWraparound mechanism in Backspace needs `x` to go beyond.
  /// </summary>
  restrictCursor([bool limitCols = true]) {
    buffer.x = min(buffer.cols - (limitCols ? 1 : 0), max(0, buffer.x));
    buffer.y = originMode
        ? min(buffer.scrollBottom, max(buffer.scrollTop, buffer.y))
        : min(buffer.rows - 1, max(0, buffer.y));

    updateRange(buffer.y);
  }

  /// <summary>
  /// Returns true if the terminal is using margins in origin mode
  /// </summary>
  bool isUsingMargins() {
    return originMode && marginMode;
  }

  // End Cursor commands

  /// <summary>
  /// Performs a carriage return
  /// </summary>
  carriageReturn() {
    if (marginMode) {
      if (buffer.x < buffer.marginLeft) {
        buffer.x = 0;
      } else {
        buffer.x = buffer.marginLeft;
      }
    } else {
      buffer.x = 0;
    }
  }

  // Text manipulation

  /// <summary>
  /// Backspace handler (Control-h)
  /// </summary>
  backspace() {
    restrictCursor(!reverseWraparound);

    int left = marginMode ? buffer.marginLeft : 0;
    int right = marginMode ? buffer.marginRight : buffer.cols - 1;

    if (buffer.x > left) {
      buffer.x--;
    } else if (reverseWraparound) {
      if (buffer.x <= left) {
        if (buffer.y > buffer.scrollTop &&
            buffer.y <= buffer.scrollBottom &&
            (buffer.lines[buffer.y + buffer.yBase]!.isWrapped || marginMode)) {
          if (!marginMode) {
            buffer.lines[buffer.y + buffer.yBase]!.isWrapped = false;
          }

          buffer.y--;
          buffer.x = right;
          // TODO: find actual last cell based on width used
        } else if (buffer.y == buffer.scrollTop) {
          buffer.x = right;
          buffer.y = buffer.scrollBottom;
        } else if (buffer.y > 0) {
          buffer.x = right;
          buffer.y--;
        }
      }
    } else {
      if (buffer.x < left) {
        // This compensates for the scenario where backspace is supposed to move one step
        // backwards if the "x" position is behind the left margin.
        // Test BS_MovesLeftWhenLeftOfLeftMargin
        buffer.x--;
      } else if (buffer.x > left) {
        // If we have not reached the limit, we can go back, otherwise stop at the margin
        // Test BS_StopsAtLeftMargin
        buffer.x--;
      }
    }
  }

  /// <summary>
  /// Deletes charstoDelete chars from the cursor position to the right margin
  /// </summary>
  deleteChars(int charsToDelete) {
    if (marginMode) {
      if (buffer.x + charsToDelete > buffer.marginRight) {
        charsToDelete = buffer.marginRight - buffer.x;
      }
    }

    buffer.lines[buffer.y + buffer.yBase]!.deleteCells(
        buffer.x,
        charsToDelete,
        marginMode ? buffer.marginRight : buffer.cols - 1,
        CharData(eraseAttr()));

    updateRange(buffer.y);
  }

  /// <summary>
  /// Deletes lines
  /// </summary>
  deleteLines(int rowsToDelete) {
    restrictCursor();
    var row = buffer.y + buffer.yBase;

    int j;
    j = buffer.rows - 1 - buffer.scrollBottom;
    j = buffer.rows - 1 + buffer.yBase - j;

    final eraseAttr = this.eraseAttr();

    if (marginMode) {
      if (buffer.x >= buffer.marginLeft && buffer.x <= buffer.marginRight) {
        var columnCount = buffer.marginRight - buffer.marginLeft + 1;
        var rowCount = buffer.scrollBottom - buffer.scrollTop;
        while (rowsToDelete-- > 0) {
          for (int i = 0; i < rowCount; i++) {
            final src = buffer.lines[row + i + 1];
            final dst = buffer.lines[row + i];

            if (src != null && dst != null) {
              dst.copyFromRange(
                  src, buffer.marginLeft, buffer.marginLeft, columnCount);
            }
          }

          final last = buffer.lines[row + rowCount];
          last?.fillRange(CharData(eraseAttr), buffer.marginLeft, columnCount);
        }
      }
    } else {
      if (buffer.y >= buffer.scrollTop && buffer.y <= buffer.scrollBottom) {
        while (rowsToDelete-- > 0) {
          buffer.lines.splice(row, 1, []);
          buffer.lines.splice(j, 0, [buffer.getBlankLine(eraseAttr)]);
        }
      }
    }

    updateRange(buffer.y);
    updateRange(buffer.scrollBottom);
  }

  /// <summary>
  /// Inserts columns
  /// </summary>
  insertColumn(int columns) {
    for (int row = buffer.scrollTop; row < buffer.scrollBottom; row++) {
      final line = buffer.lines[row + buffer.yBase];
      // TODO:is this the right filldata?
      line!.insertCells(
          buffer.x,
          columns,
          marginMode ? buffer.marginRight : buffer.cols - 1,
          CharData.whiteSpace);
      line.isWrapped = false;
    }

    updateRange(buffer.scrollTop);
    updateRange(buffer.scrollBottom);
  }

  /// <summary>
  /// Deletes columns
  /// </summary>
  deleteColumn(int columns) {
    if (buffer.y > buffer.scrollBottom || buffer.y < buffer.scrollTop) return;

    for (int row = buffer.scrollTop; row < buffer.scrollBottom; row++) {
      final line = buffer.lines[row + buffer.yBase];
      line!.deleteCells(buffer.x, columns,
          marginMode ? buffer.marginRight : buffer.cols - 1, CharData.nul);
      line.isWrapped = false;
    }

    updateRange(buffer.scrollTop);
    updateRange(buffer.scrollBottom);
  }

  // End Text manipulation

  /// <summary>
  /// Sets the scroll region
  /// </summary>
  setScrollRegion(int top, int bottom) {
    if (bottom == 0) bottom = buffer.rows;
    bottom = min(bottom, buffer.rows);

    // normalize (make zero based)
    bottom--;

    // only set the scroll region if top < bottom
    if (top < bottom) {
      buffer.scrollBottom = bottom;
      buffer.scrollTop = top;
    }

    setCursor(0, 0);
  }

  /// <summary>
  /// Performs a soft reset
  /// </summary>
  softReset() {
    cursorHidden = false;
    insertMode = false;
    originMode = false;

    wraparound = true; // defaults: xterm - true, vt100 - false
    reverseWraparound = false;
    applicationKeypad = false;
    syncScrollArea();
    applicationCursor = false;
    curAttr = CharData.DefaultAttr;

    charset = null;
    setgLevel(0);

    _savedOriginMode = false;
    _savedMarginMode = false;
    _savedWraparound = false;
    _savedReverseWraparound = false;

    buffer.scrollTop = 0;
    buffer.scrollBottom = buffer.rows - 1;
    buffer.savedAttr = CharData.DefaultAttr;
    buffer.savedY = 0;
    buffer.savedX = 0;
    buffer.setMargins(0, buffer.cols - 1);
    //conformance = .vt500
  }

  /// <summary>
  /// Reports a message to the system log
  /// </summary>
  report(String prefix, String text, List<Object?>? args) {
    print('$prefix: $text');
    if (args != null) {
      for (int i = 0; i < args.length; i++) {
        print("    $i: ${args[i]}");
      }
    }
  }

  /// <summary>
  /// Sets up the terminals initial state
  /// </summary>
  setup() {
    cursorHidden = false;

    // modes
    applicationKeypad = false;
    applicationCursor = false;
    originMode = false;
    marginMode = false;
    insertMode = false;
    wraparound = true;
    bracketedPasteMode = false;

    // charset
    charset = null;
    _gcharset = 0;
    _gLevel = 0;

    curAttr = CharData.DefaultAttr;

    mouseMode = MouseMode.Off;
    mouseProtocol = MouseProtocolEncoding.X10;

    allow80To132 = false;
    // TODO REST
  }
}

class UpdateRange {
  int startY;
  int endY;

  UpdateRange(this.startY, this.endY);
}
