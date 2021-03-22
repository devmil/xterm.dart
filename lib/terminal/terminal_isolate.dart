import 'dart:isolate';

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
        _terminal.buffer.setScrollOffsetFromBottom(msg[1]);
        break;
      case 'resize':
        if (_terminal == null) {
          break;
        }
        _terminal.resize(msg[1], msg[2]);
        break;
      case 'setScrollOffsetFromBottom':
        if (_terminal == null) {
          break;
        }
        _terminal.buffer.setScrollOffsetFromBottom(msg[1]);
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
          final newState = TerminalState(
              _terminal.buffer.scrollOffsetFromBottom,
              _terminal.buffer.scrollOffsetFromTop,
              _terminal.buffer.height,
              _terminal.invisibleHeight,
              _terminal.viewHeight,
              _terminal.viewWidth,
              _terminal.selection,
              _terminal.getSelectedText(),
              _terminal.theme.background,
              _terminal.cursorX,
              _terminal.cursorY,
              _terminal.showCursor,
              _terminal.buffer.getCellUnderCursor(),
              _terminal.theme.cursor,
              _terminal.getVisibleLines(),
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

// class UiBufferLines {
//   late final List<int?> _codePoints;
//   late final List<int> _widths;
//   late final List<TerminalColor?> _fgColors;
//   late final List<TerminalColor?> _bgColors;
//   late final List<bool> _bolds;
//   late final List<bool> _faints;
//   late final List<bool> _italics;
//   late final List<bool> _underlines;
//   late final List<bool> _blinks;
//   late final List<bool> _inverses;
//   late final List<bool> _invisibles;
//
//   late final int _width;
//   late final int _height;
//
//   int get width => _width;
//   int get height => _height;
//
//   UiBufferLines(
//       int width,
//       int height,
//       List<int?> codePoints,
//       List<int> widths,
//       List<TerminalColor?> fgColors,
//       List<TerminalColor?> bgColors,
//       List<bool> bolds,
//       List<bool> faints,
//       List<bool> italics,
//       List<bool> underlines,
//       List<bool> blinks,
//       List<bool> inverses,
//       List<bool> invisibles) {
//     _width = width;
//     _height = height;
//     _codePoints = codePoints;
//     _widths = widths;
//     _fgColors = fgColors;
//     _bgColors = bgColors;
//     _bolds = bolds;
//     _faints = faints;
//     _italics = italics;
//     _underlines = underlines;
//     _blinks = blinks;
//     _inverses = inverses;
//     _invisibles = invisibles;
//   }
//
//   static UiBufferLines fromLines(
//       int width, int height, List<BufferLine> lines) {
//     int arrayLength = width * height;
//     final codePoints = List<int?>.filled(arrayLength, null);
//     final widths = List<int>.filled(arrayLength, 1);
//     final fgColors = List<TerminalColor?>.filled(arrayLength, null);
//     final bgColors = List<TerminalColor?>.filled(arrayLength, null);
//     final bolds = List<bool>.filled(arrayLength, false);
//     final faints = List<bool>.filled(arrayLength, false);
//     final italics = List<bool>.filled(arrayLength, false);
//     final underlines = List<bool>.filled(arrayLength, false);
//     final blinks = List<bool>.filled(arrayLength, false);
//     final inverses = List<bool>.filled(arrayLength, false);
//     final invisibles = List<bool>.filled(arrayLength, false);
//
//     int row = 0;
//     for (final line in lines) {
//       final rowStartIndex = row * width;
//
//       for (var i = 0; i < line.length; i++) {
//         final cell = line.getCell(i);
//         final index = rowStartIndex + i;
//         codePoints[index] = cell.codePoint;
//         widths[index] = cell.width;
//         final attr = cell.attr;
//         if (attr != null) {
//           fgColors[index] = attr.fgColor;
//           bgColors[index] = attr.bgColor;
//           bolds[index] = attr.bold;
//           faints[index] = attr.faint;
//           italics[index] = attr.italic;
//           underlines[index] = attr.underline;
//           blinks[index] = attr.blink;
//           inverses[index] = attr.inverse;
//           invisibles[index] = attr.invisible;
//         }
//       }
//
//       row++;
//     }
//
//     return UiBufferLines(width, height, codePoints, widths, fgColors, bgColors,
//         bolds, faints, italics, underlines, blinks, inverses, invisibles);
//   }
//
//   Cell getCell(int row, int col) {
//     var index = _width * row + col;
//     return Cell(
//         codePoint: _codePoints[index],
//         width: _widths[index],
//         attr: CellAttr(
//             fgColor: _fgColors[index],
//             bgColor: _bgColors[index],
//             bold: _bolds[index],
//             faint: _faints[index],
//             italic: _italics[index],
//             underline: _underlines[index],
//             blink: _blinks[index],
//             inverse: _inverses[index],
//             invisible: _invisibles[index]));
//   }
// }

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
  Cell? cellUnderCursor;
  TerminalColor cursorColor;

  List<BufferLine> visibleLines;

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
      this.cellUnderCursor,
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
    _sendPort = await firstReceivePort.first;
    _sendPort!.send(['sendPort', _receivePort.sendPort]);
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
          _lastState = message[1];
          this.notifyListeners();
          break;
      }
    });
    _sendPort!.send(
        ['init', TerminalInitData(this.platform, this.theme, this.maxLines)]);
  }

  void stop() {
    _isolate.kill();
  }

  void poll() {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send(['requestNewStateWhenDirty']);
  }

  void refresh() {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send(['refresh']);
  }

  void clearSelection() {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send(['clearSelection']);
  }

  void onMouseTap(Position position) {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send(['mouseMode.onTap', position]);
  }

  void onPanStart(Position position) {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send(['mouseMode.onPanStart', position]);
  }

  void onPanUpdate(Position position) {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send(['mouseMode.onPanUpdate', position]);
  }

  void setScrollOffsetFromBottom(int offset) {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send(['setScrollOffsetFromBottom', offset]);
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
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send(['write', text]);
  }

  void paste(String data) {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send(['paste', data]);
  }

  void resize(int newWidth, int newHeight) {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send(['resize', newWidth, newHeight]);
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
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send(['keyInput', key, ctrl, alt, shift]);
  }
}
