import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/input/keys.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/mouse/selection.dart';
import 'package:xterm/terminal/platform.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/terminal/terminal_backend.dart';
import 'package:xterm/terminal/terminal_ui_interaction.dart';
import 'package:xterm/theme/terminal_theme.dart';
import 'package:xterm/theme/terminal_themes.dart';
import 'package:xterm/util/event_debouncer.dart';
import 'package:xterm/util/observable.dart';

enum _IsolateCommand {
  SendPort,
  Init,
  Write,
  Refresh,
  ClearSelection,
  MouseTap,
  MousePanStart,
  MousePanUpdate,
  SetScrollOffsetFromTop,
  Resize,
  OnInput,
  KeyInput,
  RequestNewStateWhenDirty,
  Paste
}

enum _IsolateEvent {
  TitleChanged,
  IconChanged,
  Bell,
  NotifyChange,
  NewState,
  Exit
}

void terminalMain(SendPort port) async {
  final rp = ReceivePort();
  port.send(rp.sendPort);

  Terminal? _terminal;

  await for (var msg in rp) {
    final _IsolateCommand action = msg[0];
    switch (action) {
      case _IsolateCommand.SendPort:
        port = msg[1];
        break;
      case _IsolateCommand.Init:
        final _TerminalInitData initData = msg[1];
        _terminal = Terminal(
            backend: initData.backend,
            onTitleChange: (String title) {
              port.send([_IsolateEvent.TitleChanged, title]);
            },
            onIconChange: (String icon) {
              port.send([_IsolateEvent.IconChanged, icon]);
            },
            onBell: () {
              port.send([_IsolateEvent.Bell]);
            },
            platform: initData.platform,
            theme: initData.theme,
            maxLines: initData.maxLines);
        _terminal.addListener(() {
          port.send([_IsolateEvent.NotifyChange]);
        });
        initData.backend?.exitCode
            .then((value) => port.send([_IsolateEvent.Exit, value]));
        port.send([_IsolateEvent.NotifyChange]);
        break;
      case _IsolateCommand.Write:
        _terminal?.write(msg[1]);
        break;
      case _IsolateCommand.Refresh:
        _terminal?.refresh();
        break;
      case _IsolateCommand.ClearSelection:
        _terminal?.selection!.clear();
        break;
      case _IsolateCommand.MouseTap:
        _terminal?.mouseMode.onTap(_terminal, msg[1]);
        break;
      case _IsolateCommand.MousePanStart:
        _terminal?.mouseMode.onPanStart(_terminal, msg[1]);
        break;
      case _IsolateCommand.MousePanUpdate:
        _terminal?.mouseMode.onPanUpdate(_terminal, msg[1]);
        break;
      case _IsolateCommand.SetScrollOffsetFromTop:
        _terminal?.setScrollOffsetFromBottom(msg[1]);
        break;
      case _IsolateCommand.Resize:
        _terminal?.resize(msg[1], msg[2]);
        break;
      case _IsolateCommand.OnInput:
        _terminal?.backend?.write(msg[1]);
        break;
      case _IsolateCommand.KeyInput:
        if (_terminal == null) {
          break;
        }
        _terminal.keyInput(msg[1],
            ctrl: msg[2], alt: msg[3], shift: msg[4], mac: msg[5]);
        break;
      case _IsolateCommand.RequestNewStateWhenDirty:
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
              _terminal.selection!,
              _terminal.getSelectedText(),
              _terminal.theme.background,
              _terminal.cursorX,
              _terminal.cursorY,
              _terminal.showCursor,
              _terminal.theme.cursor,
              _terminal
                  .getVisibleLines()
                  .map((bufferLine) =>
                      _RawPointerReadOnlyBufferLine.fromBufferLine(
                          bufferLine, _terminal!.viewWidth))
                  .toList(growable: false),
              _terminal.scrollOffset);
          port.send([_IsolateEvent.NewState, newState]);
        }
        break;
      case _IsolateCommand.Paste:
        if (_terminal == null) {
          break;
        }
        _terminal.paste(msg[1]);
        break;
    }
  }
}

class _RawPointerReadOnlyBufferLine implements ReadOnlyBufferLine {
  int _trimmedLength;
  int _rawPointerAddress;
  bool _isWrapped;
  int _useCount = 1;
  bool _freed = false;

  _RawPointerReadOnlyBufferLine._(
      this._rawPointerAddress, this._trimmedLength, this._isWrapped);

  static _RawPointerReadOnlyBufferLine fromBufferLine(
      BufferLine bufferLine, int maxCols) {
    //copy cell data to new Heap memory
    final cellData = bufferLine.getCells();
    final trimmedLength = bufferLine.getTrimmedLength(maxCols);
    final dataPtr =
        malloc.allocate<Int8>(trimmedLength * ReadOnlyBufferLine.cellSize);
    //copy data
    dataPtr.asTypedList(trimmedLength * ReadOnlyBufferLine.cellSize).setAll(
        0,
        cellData.buffer
            .asInt8List(0, trimmedLength * ReadOnlyBufferLine.cellSize));
    return _RawPointerReadOnlyBufferLine._(
        dataPtr.address, trimmedLength, bufferLine.isWrapped);
  }

  void _ensureNotFreed() {
    if (_freed) {
      throw Exception('Invalid use of a already freed BufferLine!');
    }
  }

  Pointer<Int8> _getDataPtr() {
    _ensureNotFreed();
    return Pointer<Int8>.fromAddress(_rawPointerAddress);
  }

  ByteData? _lineByteDataCache;

  ByteData get _lineByteData {
    if (_lineByteDataCache == null) {
      final data = _getDataPtr()
          .asTypedList(ReadOnlyBufferLine.cellSize * _trimmedLength);
      _lineByteDataCache =
          ByteData.view(data.buffer, data.offsetInBytes, data.length);
    }
    return _lineByteDataCache!;
  }

  void registerUsage() {
    _useCount++;
  }

  void unregisterUsage() {
    if (_useCount <= 0) {
      return;
    }
    _useCount--;
    if (_useCount == 0) {
      malloc.free(_getDataPtr());
      _freed = true;
    }
  }

  int _get32BitValue(int cellIndex, int offset, [defaultValue = 0]) {
    if (cellIndex >= _trimmedLength) {
      return defaultValue;
    }
    return _lineByteData
        .getInt32(cellIndex * ReadOnlyBufferLine.cellSize + offset);
  }

  int _get8BitValue(int cellIndex, int offset, [defaultValue = 0]) {
    if (cellIndex >= _trimmedLength) {
      return defaultValue;
    }
    return _lineByteData
        .getInt8(cellIndex * ReadOnlyBufferLine.cellSize + offset);
  }

  @override
  int cellGetBgColor(int index) =>
      _get32BitValue(index, ReadOnlyBufferLine.cellBgColor, 0);

  @override
  int cellGetContent(int index) =>
      _get32BitValue(index, ReadOnlyBufferLine.cellContent, 0);

  @override
  int cellGetFgColor(int index) =>
      _get32BitValue(index, ReadOnlyBufferLine.cellFgColor, 0);

  @override
  int cellGetFlags(int index) =>
      _get8BitValue(index, ReadOnlyBufferLine.cellFlags, 0);

  @override
  int cellGetWidth(int index) =>
      _get8BitValue(index, ReadOnlyBufferLine.cellWidth, 0);

  @override
  bool cellHasContent(int index) => cellGetContent(index) != 0;

  @override
  bool cellHasFlag(int index, int flag) {
    return cellGetFlags(index) & flag != 0;
  }

  @override
  int getTrimmedLength([int? cols]) => _trimmedLength;

  @override
  bool get isWrapped => _isWrapped;
}

class _TerminalInitData {
  PlatformBehavior platform;
  TerminalTheme theme;
  int maxLines;
  TerminalBackend? backend;
  _TerminalInitData(this.backend, this.platform, this.theme, this.maxLines);
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

  int backgroundColor;

  int cursorX;
  int cursorY;
  bool showCursor;
  int cursorColor;

  List<ReadOnlyBufferLine> visibleLines;

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
      this.cursorColor,
      this.visibleLines,
      this.scrollOffset);
}

void _defaultBellHandler() {}
void _defaultTitleHandler(String _) {}
void _defaultIconHandler(String _) {}

class TerminalIsolate with Observable implements TerminalUiInteraction {
  final _receivePort = ReceivePort();
  SendPort? _sendPort;
  late Isolate _isolate;

  final TerminalBackend? backend;
  final BellHandler onBell;
  final TitleChangeHandler onTitleChange;
  final IconChangeHandler onIconChange;
  final PlatformBehavior _platform;

  final TerminalTheme theme;
  final int maxLines;

  final Duration minRefreshDelay;
  final EventDebouncer _refreshEventDebouncer;

  TerminalState? _lastState;
  final _backendExited = Completer<int>();
  Future<int> get backendExited => _backendExited.future;

  TerminalState? get lastState {
    return _lastState;
  }

  TerminalIsolate(
      {this.backend,
      this.onBell = _defaultBellHandler,
      this.onTitleChange = _defaultTitleHandler,
      this.onIconChange = _defaultIconHandler,
      PlatformBehavior platform = PlatformBehaviors.unix,
      this.theme = TerminalThemes.defaultTheme,
      this.minRefreshDelay = const Duration(milliseconds: 16),
      required this.maxLines})
      : _platform = platform,
        _refreshEventDebouncer = EventDebouncer(minRefreshDelay);

  @override
  int get scrollOffsetFromBottom => _lastState!.scrollOffsetFromBottom;

  @override
  int get scrollOffsetFromTop => _lastState!.scrollOffsetFromTop;

  @override
  int get scrollOffset => _lastState!.scrollOffset;

  @override
  int get bufferHeight => _lastState!.bufferHeight;

  @override
  int get terminalHeight => _lastState!.viewHeight;

  @override
  int get terminalWidth => _lastState!.viewWidth;

  @override
  int get invisibleHeight => _lastState!.invisibleHeight;

  @override
  Selection? get selection => _lastState?.selection;

  @override
  bool get showCursor => _lastState?.showCursor ?? true;

  @override
  List<ReadOnlyBufferLine> getVisibleLines() {
    if (_lastState == null) {
      return List<BufferLine>.empty();
    }
    return _lastState!.visibleLines;
  }

  @override
  int get cursorY => _lastState?.cursorY ?? 0;

  @override
  int get cursorX => _lastState?.cursorX ?? 0;

  @override
  ReadOnlyBufferLine? get currentLine {
    if (_lastState == null) {
      return null;
    }

    int visibleLineIndex =
        _lastState!.cursorY - _lastState!.scrollOffsetFromTop;
    if (visibleLineIndex < 0) {
      visibleLineIndex = _lastState!.cursorY;
    }
    return _lastState!.visibleLines[visibleLineIndex];
  }

  @override
  int get cursorColor => _lastState?.cursorColor ?? 0;

  @override
  int get backgroundColor => _lastState?.backgroundColor ?? 0;

  @override
  bool get dirty {
    if (_lastState == null) {
      return false;
    }
    if (_lastState!.consumed) {
      return false;
    }
    _lastState!.consumed = true;
    return true;
  }

  @override
  PlatformBehavior get platform => _platform;

  @override
  bool get isReady => _lastState != null;

  void start() async {
    final initialRefreshCompleted = Completer<bool>();
    var firstReceivePort = ReceivePort();
    _isolate = await Isolate.spawn(terminalMain, firstReceivePort.sendPort);
    _sendPort = await firstReceivePort.first;
    _sendPort!.send([_IsolateCommand.SendPort, _receivePort.sendPort]);
    _receivePort.listen((message) {
      _IsolateEvent action = message[0];
      switch (action) {
        case _IsolateEvent.Bell:
          this.onBell();
          break;
        case _IsolateEvent.TitleChanged:
          this.onTitleChange(message[1]);
          break;
        case _IsolateEvent.IconChanged:
          this.onIconChange(message[1]);
          break;
        case _IsolateEvent.NotifyChange:
          _refreshEventDebouncer.notifyEvent(() {
            poll();
          });
          break;
        case _IsolateEvent.NewState:
          if (_lastState != null) {
            _lastState!.visibleLines
                .cast<_RawPointerReadOnlyBufferLine>()
                .forEach((bl) {
              bl.unregisterUsage();
            });
          }
          _lastState = message[1];
          if (!initialRefreshCompleted.isCompleted) {
            initialRefreshCompleted.complete(true);
          }
          this.notifyListeners();
          break;
        case _IsolateEvent.Exit:
          _backendExited.complete(message[1]);
          break;
      }
    });
    _sendPort!.send([
      _IsolateCommand.Init,
      _TerminalInitData(this.backend, this.platform, this.theme, this.maxLines)
    ]);
    await initialRefreshCompleted.future;
  }

  void stop() {
    _isolate.kill();
  }

  void poll() {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send([_IsolateCommand.RequestNewStateWhenDirty]);
  }

  void refresh() {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send([_IsolateCommand.Refresh]);
  }

  void clearSelection() {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send([_IsolateCommand.ClearSelection]);
  }

  void onMouseTap(Position position) {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send([_IsolateCommand.MouseTap, position]);
  }

  void onPanStart(Position position) {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send([_IsolateCommand.MousePanStart, position]);
  }

  void onPanUpdate(Position position) {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send([_IsolateCommand.MousePanUpdate, position]);
  }

  void setScrollOffsetFromBottom(int offset) {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send([_IsolateCommand.SetScrollOffsetFromTop, offset]);
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
    _sendPort!.send([_IsolateCommand.Write, text]);
  }

  void paste(String data) {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send([_IsolateCommand.Paste, data]);
  }

  void resize(int newWidth, int newHeight) {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send([_IsolateCommand.Resize, newWidth, newHeight]);
  }

  void raiseOnInput(String text) {
    _sendPort!.send([_IsolateCommand.OnInput, text]);
  }

  void keyInput(
    TerminalKey key, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
    bool mac = false,
    // bool meta,
  }) {
    if (_sendPort == null) {
      return;
    }
    _sendPort!.send([_IsolateCommand.KeyInput, key, ctrl, alt, shift, mac]);
  }
}
