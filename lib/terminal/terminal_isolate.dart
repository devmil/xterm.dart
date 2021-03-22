import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/cell.dart';
import 'package:xterm/buffer/cell_attr.dart';
import 'package:xterm/input/keys.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/mouse/selection.dart';
import 'package:xterm/terminal/platform.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/terminal/terminal_ui_interaction.dart';
import 'package:xterm/theme/terminal_color.dart';
import 'package:xterm/theme/terminal_theme.dart';
import 'package:xterm/theme/terminal_themes.dart';
import 'package:xterm/utli/observable.dart';

void terminalMain(SendPort port) async {
  final rp = ReceivePort();
  port.send(rp.sendPort);

  Terminal? _terminal;

  await for (var msg in rp) {
    final String action = msg[0];
    switch (action) {
      case 'sendPort':
        port = msg[1];
        break;
      case 'init':
        final TerminalInitData initData = msg[1];
        _terminal = Terminal(
            onInput: (String input) {
              port.send(['onInput', input]);
            },
            onTitleChange: (String title) {
              port.send(['onTitleChange', title]);
            },
            onIconChange: (String icon) {
              port.send(['onIconChange', icon]);
            },
            onBell: () {
              port.send(['onBell']);
            },
            platform: initData.platform,
            theme: initData.theme,
            maxLines: initData.maxLines);
        _terminal.addListener(() {
          port.send(['notify']);
        });
        break;
      case 'write':
        if (_terminal == null) {
          break;
        }
        _terminal.write(msg[1]);
        break;
      case 'refresh':
        if (_terminal == null) {
          break;
        }

        _terminal.refresh();
        break;
      case 'selection.clear':
        if (_terminal == null) {
          break;
        }
        _terminal.selection.clear();
        break;
      case 'mouseMode.onTap':
        if (_terminal == null) {
          break;
        }
        _terminal.mouseMode.onTap(_terminal, msg[1]);
        break;
      case 'mouseMode.onPanStart':
        if (_terminal == null) {
          break;
        }
        _terminal.mouseMode.onPanStart(_terminal, msg[1]);
        break;
      case 'mouseMode.onPanUpdate':
        if (_terminal == null) {
          break;
        }
        _terminal.mouseMode.onPanUpdate(_terminal, msg[1]);
        break;
      case 'setScrollOffsetFromBottom':
        if (_terminal == null) {
          break;
        }
        _terminal.setScrollOffsetFromBottom(msg[1]);
        break;
      case 'resize':
        if (_terminal == null) {
          break;
        }
        _terminal.resize(msg[1], msg[2]);
        break;
      case 'keyInput':
        if (_terminal == null) {
          break;
        }
        _terminal.keyInput(msg[1], ctrl: msg[2], alt: msg[3], shift: msg[4]);
        break;
      case 'requestNewStateWhenDirty':
        if (_terminal == null) {
          break;
        }
        if (_terminal.dirty) {
          int? cellWidthUnderCursor;
          if (_terminal.buffer.getCellUnderCursor() != null) {
            cellWidthUnderCursor = _terminal.buffer.getCellUnderCursor()!.width;
          }
          final newState = TerminalState(
              _terminal.buffer.scrollOffsetFromBottom,
              _terminal.buffer.scrollOffsetFromTop,
              _terminal.buffer.height,
              _terminal.invisibleHeight,
              _terminal.viewHeight,
              _terminal.viewWidth,
              _terminal.selection,
              _terminal.getSelectedText(),
              TerminalColor(_terminal.theme.background.value),
              _terminal.cursorX,
              _terminal.cursorY,
              _terminal.showCursor,
              cellWidthUnderCursor,
              TerminalColor(_terminal.theme.cursor.value),
              UiBufferLines.fromLines(_terminal.viewWidth, _terminal.viewHeight,
                  _terminal.getVisibleLines()),
              _terminal.scrollOffset);
          port.send(['newState', newState]);
        }
        break;
      case 'paste':
        if (_terminal == null) {
          break;
        }
        _terminal.paste(msg[1]);
        break;
    }
  }
}

class TerminalInitData {
  PlatformBehavior platform;
  TerminalTheme theme;
  int? maxLines;

  TerminalInitData(this.platform, this.theme, this.maxLines);
}

class UiBufferLines {
  late final List<int> _rawDataPtr;

  late final int _cellDataSize;
  late final int _codePointOffset;
  late final int _widthOffset;
  late final int _fgColorOffset;
  late final int _bgColorOffset;
  late final int _flagsOffset;

  late final int _width;
  late final int _height;

  int get width => _width;
  int get height => _height;

  bool freeBufferOnNoUsage;
  int _usages = 0;

  bool _freed = false;

  Pointer<Int64> _getRawData(int line) {
    checkFreed();
    if (line >= _rawDataPtr.length) {
      throw ArgumentError.value(line);
    }
    return Pointer<Int64>.fromAddress(_rawDataPtr[line]);
  }

  static const int FLAG_OFFSET_BOLD = 0;
  static const int FLAG_OFFSET_FAINT = 1;
  static const int FLAG_OFFSET_ITALIC = 2;
  static const int FLAG_OFFSET_UNDERLINE = 3;
  static const int FLAG_OFFSET_BLINK = 4;
  static const int FLAG_OFFSET_INVERSE = 5;
  static const int FLAG_OFFSET_INVISIBLE = 6;

  UiBufferLines(
      int width,
      int height,
      List<Pointer<Int64>> rawData,
      int cellDataSize,
      int codePointOffset,
      int widthOffset,
      int fgColorOffset,
      int bgColorOffset,
      int flagsOffset,
      {this.freeBufferOnNoUsage = false}) {
    _width = width;
    _height = height;
    _rawDataPtr =
        List<int>.generate(rawData.length, (index) => rawData[index].address);
    _cellDataSize = cellDataSize;
    _codePointOffset = codePointOffset;
    _widthOffset = widthOffset;
    _fgColorOffset = fgColorOffset;
    _bgColorOffset = bgColorOffset;
    _flagsOffset = flagsOffset;
  }

  static UiBufferLines fromLines(
      int width, int height, List<BufferLine> lines) {
    var codePointOffset = 0;
    var codePointSize = 1;
    var widthOffset = codePointOffset + codePointSize;
    var widthSize = 1;
    var fgColorOffset = widthOffset + widthSize;
    var fgColorSize = 1;
    var bgColorOffset = fgColorOffset + fgColorSize;
    var bgColorSize = 1;
    var flagsOffset = bgColorOffset + bgColorSize;
    var flagsSize = 1;

    var cellDataSize = flagsOffset + flagsSize;

    //allocate Heap memory
    var dataCount = width * cellDataSize;
    final rawDataLines = List<Pointer<Int64>>.empty(growable: true);
    int row = 0;
    for (final line in lines) {
      var rawData = calloc<Int64>(dataCount);
      rawDataLines.add(rawData);
      final rowStartOffset = 0;

      for (var i = 0; i < min(width, line.length); i++) {
        final cell = line.getCell(i);
        final cellDataOffset = rowStartOffset + i * cellDataSize;

        if (cell.codePoint != null) {
          rawData.elementAt(cellDataOffset + codePointOffset).value =
              cell.codePoint!;
        }
        rawData.elementAt(cellDataOffset + widthOffset).value = cell.width;

        final attr = cell.attr;
        if (attr != null) {
          if (attr.fgColor != null) {
            rawData.elementAt(cellDataOffset + fgColorOffset).value =
                attr.fgColor!.value;
          }
          if (attr.bgColor != null) {
            rawData.elementAt(cellDataOffset + bgColorOffset).value =
                attr.bgColor!.value;
          }

          int flags = 0;
          if (attr.bold) {
            flags |= 0x01 << FLAG_OFFSET_BOLD;
          }
          if (attr.faint) {
            flags |= 0x01 << FLAG_OFFSET_FAINT;
          }
          if (attr.italic) {
            flags |= 0x01 << FLAG_OFFSET_ITALIC;
          }
          if (attr.underline) {
            flags |= 0x01 << FLAG_OFFSET_UNDERLINE;
          }
          if (attr.blink) {
            flags |= 0x01 << FLAG_OFFSET_BLINK;
          }
          if (attr.inverse) {
            flags |= 0x01 << FLAG_OFFSET_INVERSE;
          }
          if (attr.invisible) {
            flags |= 0x01 << FLAG_OFFSET_INVISIBLE;
          }

          rawData.elementAt(cellDataOffset + flagsOffset).value = flags;
        }
      }

      row++;
    }

    //add empty rows for missing lines
    for (int i = lines.length; i < height; i++) {
      var rawData = calloc<Int64>(dataCount);
      rawDataLines.add(rawData);
    }

    return UiBufferLines(
        width,
        height,
        rawDataLines,
        cellDataSize,
        codePointOffset,
        widthOffset,
        fgColorOffset,
        bgColorOffset,
        flagsOffset);
  }

  void addUsage() {
    _usages++;
  }

  void removeUsage() {
    _usages--;
    if (_usages <= 0 && freeBufferOnNoUsage) {
      free();
    }
  }

  void free() {
    checkFreed();
    _rawDataPtr.forEach((element) {
      calloc.free(Pointer<Int64>.fromAddress(element));
    });
    _freed = true;
  }

  int _offsetFromCoordinates(int x, int y) {
    return (/*_width * y + */ x) * _cellDataSize;
  }

  bool hasData(int x, int y) {
    if (x > _width || y > _height) {
      return false;
    }
    final cellOffset = _offsetFromCoordinates(x, y);
    return _getRawData(y).elementAt(cellOffset + _codePointOffset).value != 0;
  }

  int codePointAt(int x, int y) {
    if (x > _width || y > _height) {
      return 0;
    }
    final cellOffset = _offsetFromCoordinates(x, y);
    return _getRawData(y).elementAt(cellOffset + _codePointOffset).value;
  }

  int widthAt(int x, int y) {
    if (x > _width || y > _height) {
      return 0;
    }
    final cellOffset = _offsetFromCoordinates(x, y);
    return _getRawData(y).elementAt(cellOffset + _widthOffset).value;
  }

  TerminalColor? fgColorAt(int x, int y) {
    if (x > _width || y > _height) {
      return null;
    }
    final cellOffset = _offsetFromCoordinates(x, y);
    final colorVal =
        _getRawData(y).elementAt(cellOffset + _fgColorOffset).value;
    //TODO: might be a problem for white
    if (colorVal == 0) {
      return null;
    }
    return TerminalColor(colorVal);
  }

  TerminalColor? bgColorAt(int x, int y) {
    if (x > _width || y > _height) {
      return null;
    }
    final cellOffset = _offsetFromCoordinates(x, y);
    final colorVal =
        _getRawData(y).elementAt(cellOffset + _bgColorOffset).value;
    //TODO: might be a problem for white
    if (colorVal == 0) {
      return null;
    }
    return TerminalColor(colorVal);
  }

  bool _getFlag(int x, int y, int offset) {
    if (x > _width || y > _height) {
      return false;
    }
    final cellOffset = _offsetFromCoordinates(x, y);
    int flags = _getRawData(y).elementAt(cellOffset + _flagsOffset).value;
    int mask = 0x01 << offset;
    return (flags & mask) != 0;
  }

  int flagsAt(int x, int y) {
    if (x > _width || y > _height) {
      return 0;
    }
    final cellOffset = _offsetFromCoordinates(x, y);
    return _getRawData(y).elementAt(cellOffset + _flagsOffset).value;
  }

  bool isBoldAt(int x, int y) {
    return _getFlag(x, y, FLAG_OFFSET_BOLD);
  }

  bool isFaintAt(int x, int y) {
    return _getFlag(x, y, FLAG_OFFSET_FAINT);
  }

  bool isItalicAt(int x, int y) {
    return _getFlag(x, y, FLAG_OFFSET_ITALIC);
  }

  bool isUnderlineAt(int x, int y) {
    return _getFlag(x, y, FLAG_OFFSET_UNDERLINE);
  }

  bool isBlinkAt(int x, int y) {
    return _getFlag(x, y, FLAG_OFFSET_BLINK);
  }

  bool isInverseAt(int x, int y) {
    return _getFlag(x, y, FLAG_OFFSET_INVERSE);
  }

  bool isInvisibleAt(int x, int y) {
    return _getFlag(x, y, FLAG_OFFSET_INVISIBLE);
  }

  void checkFreed() {
    if (_freed) {
      throw Exception("Bufferlines already freed but still gets used!");
    }
  }
}

class TerminalState {
  int scrollOffsetFromTop;
  int scrollOffsetFromBottom;

  int bufferHeight;
  int invisibleHeight;

  int viewHeight;
  int viewWidth;

  Selection selection;
  String? selectedText;

  TerminalColor backgroundColor;

  int cursorX;
  int cursorY;
  bool showCursor;
  int? cellWidthUnderCursor;
  TerminalColor cursorColor;

  UiBufferLines visibleLines;

  int scrollOffset;

  bool consumed = false;

  TerminalState(
      this.scrollOffsetFromBottom,
      this.scrollOffsetFromTop,
      this.bufferHeight,
      this.invisibleHeight,
      this.viewHeight,
      this.viewWidth,
      this.selection,
      this.selectedText,
      this.backgroundColor,
      this.cursorX,
      this.cursorY,
      this.showCursor,
      this.cellWidthUnderCursor,
      this.cursorColor,
      this.visibleLines,
      this.scrollOffset);
}

void _defaultInputHandler(String _) {}
void _defaultBellHandler() {}
void _defaultTitleHandler(String _) {}
void _defaultIconHandler(String _) {}

class TerminalIsolate with Observable implements TerminalUiInteraction {
  final _receivePort = ReceivePort();
  SendPort? _sendPort;
  late Isolate _isolate;

  final TerminalInputHandler onInput;
  final BellHandler onBell;
  final TitleChangeHandler onTitleChange;
  final IconChangeHandler onIconChange;
  final PlatformBehavior platform;

  final TerminalTheme theme;
  final int? maxLines;

  TerminalState? _lastState;

  TerminalState? get lastState {
    return _lastState;
  }

  final _pendingMessages = List<Object>.empty(growable: true);

  TerminalIsolate(
      {this.onInput = _defaultInputHandler,
      this.onBell = _defaultBellHandler,
      this.onTitleChange = _defaultTitleHandler,
      this.onIconChange = _defaultIconHandler,
      this.platform = PlatformBehaviors.unix,
      this.theme = TerminalThemes.defaultTheme,
      this.maxLines});

  void start() async {
    var firstReceivePort = ReceivePort();
    _isolate = await Isolate.spawn(terminalMain, firstReceivePort.sendPort);
    final sendPort = await firstReceivePort.first;
    sendPort!.send(['sendPort', _receivePort.sendPort]);
    _receivePort.listen((message) {
      String action = message[0];
      switch (action) {
        case 'onInput':
          this.onInput(message[1]);
          break;
        case 'onBell':
          this.onBell();
          break;
        case 'onTitleChange':
          this.onTitleChange(message[1]);
          break;
        case 'onIconChange':
          this.onIconChange(message[1]);
          break;
        case 'notify':
          poll();
          break;
        case 'newState':
          if (_lastState != null) {
            _lastState!.visibleLines.removeUsage();
          }
          _lastState = message[1];
          _lastState!.visibleLines.addUsage();
          _lastState!.visibleLines.freeBufferOnNoUsage = true;
          this.notifyListeners();
          break;
      }
    });
    sendPort!.send(
        ['init', TerminalInitData(this.platform, this.theme, this.maxLines)]);
    _sendPort = sendPort;
    _pendingMessages.forEach((element) {
      _sendMessage(element);
    });
    _pendingMessages.clear();
  }

  void stop() {
    _isolate.kill();
  }

  void _sendMessage(Object message) {
    if (_sendPort == null) {
      _pendingMessages.add(message);
      return;
    }
    _sendPort!.send(message);
  }

  void poll() {
    _sendMessage(['requestNewStateWhenDirty']);
  }

  void refresh() {
    _sendMessage(['refresh']);
  }

  void clearSelection() {
    _sendMessage(['clearSelection']);
  }

  void onMouseTap(Position position) {
    _sendMessage(['mouseMode.onTap', position]);
  }

  void onPanStart(Position position) {
    _sendMessage(['mouseMode.onPanStart', position]);
  }

  void onPanUpdate(Position position) {
    _sendMessage(['mouseMode.onPanUpdate', position]);
  }

  void setScrollOffsetFromBottom(int offset) {
    _sendMessage(['setScrollOffsetFromBottom', offset]);
  }

  int convertViewLineToRawLine(int viewLine) {
    if (_lastState == null) {
      return 0;
    }
    if (_lastState!.viewHeight > _lastState!.bufferHeight) {
      return viewLine;
    }

    return viewLine + (_lastState!.bufferHeight - _lastState!.viewHeight);
  }

  void write(String text) {
    _sendMessage(['write', text]);
  }

  void paste(String data) {
    _sendMessage(['paste', data]);
  }

  void resize(int newWidth, int newHeight) {
    _sendMessage(['resize', newWidth, newHeight]);
  }

  void raiseOnInput(String text) {
    onInput(text);
  }

  void keyInput(
    TerminalKey key, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
    // bool meta,
  }) {
    _sendMessage(['keyInput', key, ctrl, alt, shift]);
  }
}
