import 'dart:math' as math;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:xterm/buffer/char_attribute_utils.dart';
import 'package:xterm/buffer/char_data.dart';
import 'package:xterm/frontend/char_size.dart';
import 'package:xterm/frontend/helpers.dart';
import 'package:xterm/frontend/input_behavior.dart';
import 'package:xterm/frontend/input_behaviors.dart';
import 'package:xterm/frontend/input_listener.dart';
import 'package:xterm/frontend/cache.dart';
import 'package:xterm/input/mouse_mode.dart';
import 'package:xterm/input/terminal_color_code.dart';
import 'package:xterm/renderer/renderer.dart';
import 'package:xterm/terminal/selection_service.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/terminal/terminal_delegate.dart';
import 'package:xterm/theme/terminal_color.dart';
import 'package:xterm/theme/terminal_style.dart';
import 'package:xterm/theme/terminal_theme.dart';
import 'package:xterm/theme/terminal_themes.dart';

typedef TerminalResizeHandler = void Function(int width, int height);

class TerminalView extends StatefulWidget {
  TerminalView({
    Key? key,
    required this.terminal,
    required this.selection,
    this.onResize,
    this.style = const TerminalStyle(),
    this.opacity = 1.0,
    FocusNode? focusNode,
    this.autofocus = false,
    ScrollController? scrollController,
    InputBehavior? inputBehavior,
  })  : focusNode = focusNode ?? FocusNode(),
        scrollController = scrollController ?? ScrollController(),
        inputBehavior = inputBehavior ?? InputBehaviors.platform,
        super(key: key ?? ValueKey(terminal));

  final Terminal terminal;
  final SelectionService selection;
  final TerminalResizeHandler? onResize;
  final FocusNode focusNode;
  final bool autofocus;
  final ScrollController scrollController;

  final TerminalStyle style;
  final double opacity;

  final InputBehavior inputBehavior;

  // get the dimensions of a rendered character
  CellSize measureCellSize() {
    final testString = 'xxxxxxxxxx' * 1000;

    final text = Text(
      testString,
      style: (style.textStyleProvider != null)
          ? style.textStyleProvider!(
              fontSize: style.fontSize,
            )
          : TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: style.fontFamily,
              fontSize: style.fontSize,
            ),
    );

    final size = textSize(text);

    final charWidth = (size.width / testString.length);
    final charHeight = size.height;

    final cellWidth = charWidth * style.fontWidthScaleFactor;
    final cellHeight = size.height * style.fontHeightScaleFactor;

    return CellSize(
      charWidth: charWidth,
      charHeight: charHeight,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      letterSpacing: cellWidth - charWidth,
      lineSpacing: cellHeight - charHeight,
    );
  }

  @override
  _TerminalViewState createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  bool get focused {
    return widget.focusNode.hasFocus;
  }

  int? _lastTerminalWidth;
  int? _lastTerminalHeight;

  late CellSize _cellSize;

  void onTerminalChange() {
    final currentScrollExtent =
        _cellSize.cellHeight * widget.terminal.buffer.yBase;

    widget.scrollController.jumpTo(currentScrollExtent);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    // measureCellSize is expensive so we cache the result.
    _cellSize = widget.measureCellSize();

    widget.terminal.addListener(onTerminalChange);
    widget.selection.onSelectionChanged = onTerminalChange;

    super.initState();
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    oldWidget.terminal.removeListener(onTerminalChange);
    widget.terminal.addListener(onTerminalChange);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    // oscillator.stop();
    // oscillator.removeListener(onTick);

    widget.terminal.removeListener(onTerminalChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InputListener(
      listenKeyStroke: widget.inputBehavior.acceptKeyStroke,
      onKeyStroke: onKeyStroke,
      onTextInput: onInput,
      onAction: onAction,
      onFocus: onFocus,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      initEditingState: widget.inputBehavior.initEditingState,
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: LayoutBuilder(builder: (context, constraints) {
          onResize(constraints.maxWidth, constraints.maxHeight);
          // use flutter's Scrollable to manage scrolling to better integrate
          // with widgets such as Scrollbar.
          return NotificationListener<UserScrollNotification>(
            onNotification: (_) {
              onScroll(_.metrics.pixels);
              return false;
            },
            child: Scrollable(
              controller: widget.scrollController,
              viewportBuilder: (context, offset) {
                // set viewport height.
                offset.applyViewportDimension(constraints.maxHeight);

                final minScrollExtent = 0.0;

                final maxScrollExtent = math.max(
                    0.0,
                    _cellSize.cellHeight * widget.terminal.buffer.lines.length -
                        constraints.maxHeight);

                // set how much the terminal can scroll
                offset.applyContentDimensions(minScrollExtent, maxScrollExtent);

                return buildTerminal(context);
              },
            ),
          );
        }),
      ),
    );
  }

  Widget buildTerminal(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      dragStartBehavior: DragStartBehavior.down,
      onTapDown: (detail) {
        if (!widget.selection.isActive) {
          InputListener.of(context)!.requestKeyboard();
        } else {
          widget.selection.selectNone();
        }
        final pos = detail.localPosition;
        final offset = getMouseOffset(pos.dx, pos.dy);

        if (widget.terminal.mouseMode != MouseMode.Off) {
          final encodedMouseButton = widget.terminal.encodeMouseButton(
              1, false, _shiftPressed, _metaPressed, _controlPressed);
          widget.terminal.sendEvent(encodedMouseButton, offset.x, offset.y);
        }
      },
      onPanStart: (detail) {
        final pos = detail.localPosition;
        final offset = getMouseOffset(pos.dx, pos.dy);
        widget.selection.startSelection(offset.y, offset.x);
      },
      onPanUpdate: (detail) {
        final pos = detail.localPosition;
        final offset = getMouseOffset(pos.dx, pos.dy);
        widget.selection.dragExtend(offset.y, offset.x);
      },
      child: Container(
        constraints: BoxConstraints.expand(),
        child: CustomPaint(
          painter: TerminalPainter(
            terminal: widget.terminal,
            selection: widget.selection,
            view: widget,
            focused: focused,
            charSize: _cellSize,
          ),
        ),
        //TODO: use dominant background color
        color: Color(TerminalThemes.defaultTheme.background.value)
            .withOpacity(widget.opacity),
      ),
    );
  }

  math.Point<int> getMouseOffset(double px, double py) {
    final col = (px / _cellSize.cellWidth).floor();
    final row = (py / _cellSize.cellHeight).floor();

    return math.Point<int>(col, row);
  }

  void onResize(double width, double height) {
    final termWidth = (width / _cellSize.cellWidth).floor();
    final termHeight = (height / _cellSize.cellHeight).floor();

    if (_lastTerminalWidth != termWidth || _lastTerminalHeight != termHeight) {
      _lastTerminalWidth = termWidth;
      _lastTerminalHeight = termHeight;

      // print('($termWidth, $termHeight)');

      widget.onResize?.call(termWidth, termHeight);

      SchedulerBinding.instance!.addPostFrameCallback((_) {
        widget.terminal.resize(termWidth, termHeight);
      });

      // Future.delayed(Duration.zero).then((_) {
      //   widget.terminal.resize(termWidth, termHeight);
      // });
    }
  }

  TextEditingValue? onInput(TextEditingValue value) {
    return widget.inputBehavior.onTextEdit(value, widget.terminal);
  }

  bool _shiftPressed = false;
  bool _altPressed = false;
  bool _controlPressed = false;
  bool _metaPressed = false;

  void onKeyStroke(RawKeyEvent event) {
    _shiftPressed = event.isShiftPressed;
    _altPressed = event.isAltPressed;
    _controlPressed = event.isControlPressed;
    _metaPressed = event.isMetaPressed;

    widget.inputBehavior.onKeyStroke(event, widget.terminal);
    var cursorYPos = widget.terminal.buffer.yBase;
    var linesToScroll = cursorYPos - widget.terminal.buffer.yDisp;
    if (linesToScroll != 0) {
      widget.terminal.scrollLines(linesToScroll);
    }
  }

  void onFocus(bool focused) {
    SchedulerBinding.instance!.addPostFrameCallback((_) {
      //TODO: refresh on Focus?
      //widget.terminal.refresh();
    });
  }

  void onAction(TextInputAction action) {
    widget.inputBehavior.onAction(action, widget.terminal);
  }

  // synchronize flutter scroll offset to terminal
  void onScroll(double offset) {
    final desiredCursorYPos = (offset / _cellSize.cellHeight).ceil();
    var cursorYPos = widget.terminal.buffer.yBase;
    var linesToScroll = desiredCursorYPos - cursorYPos;

    if (linesToScroll != 0) {
      setState(() {
        widget.terminal.scrollLines(linesToScroll);
      });
    }
  }
}

class TerminalPainter extends CustomPainter {
  TerminalPainter({
    required this.terminal,
    required this.selection,
    required this.view,
    required this.focused,
    required this.charSize,
  });

  final Terminal terminal;
  final SelectionService selection;
  final TerminalView view;
  final bool focused;
  final CellSize charSize;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas);

    // if (oscillator.value) {
    // }

    if (!terminal.cursorHidden) {
      _paintCursor(canvas);
    }

    _paintText(canvas);

    _paintSelection(canvas);

    terminal.clearUpdateRange();
  }

  TerminalColor _getColor(
      int colorCode, TerminalColor defaultColor, TerminalTheme theme) {
    if (colorCode == Renderer.DefaultColor) {
      return defaultColor;
    }
    final terminalColorCode = TerminalColorCodeExtension.fromValue(colorCode);
    if (terminalColorCode != null) {
      //map terminal color code to theme
      switch (terminalColorCode) {
        case TerminalColorCode.Black:
          return theme.black;
        case TerminalColorCode.Red:
          return theme.red;
        case TerminalColorCode.Green:
          return theme.green;
        case TerminalColorCode.Yellow:
          return theme.yellow;
        case TerminalColorCode.Blue:
          return theme.blue;
        case TerminalColorCode.Magenta:
          return theme.magenta;
        case TerminalColorCode.Cyan:
          return theme.cyan;
        case TerminalColorCode.White:
          return theme.white;
        case TerminalColorCode.BrightBlack:
          return theme.brightBlack;
        case TerminalColorCode.BrightRed:
          return theme.brightRed;
        case TerminalColorCode.BrightGreen:
          return theme.brightGreen;
        case TerminalColorCode.BrightYellow:
          return theme.brightYellow;
        case TerminalColorCode.BrightBlue:
          return theme.brightBlue;
        case TerminalColorCode.BrightMagenta:
          return theme.brightMagenta;
        case TerminalColorCode.BrightCyan:
          return theme.brightCyan;
        case TerminalColorCode.BrightWhite:
          return theme.brightWhite;
        case TerminalColorCode.Default:
          return defaultColor;
      }
    }
    //try to extract RGB values
    return TerminalColor(colorCode);
  }

  void _paintBackground(Canvas canvas) {
    final lines = terminal.buffer.lines;

    for (var i = 0; i < terminal.rows; i++) {
      final line = lines[terminal.buffer.yDisp + i];
      if (line == null) {
        continue;
      }
      final offsetY = i * charSize.cellHeight;
      final cellCount = math.min(terminal.cols, line.length);

      for (var i = 0; i < cellCount; i++) {
        final cell = line[i];
        final attr = cell.attribute;

        if (cell.width == 0) {
          continue;
        }

        final offsetX = i * charSize.cellWidth;
        final effectWidth = charSize.cellWidth * cell.width + 1;
        final effectHeight = charSize.cellHeight + 1;

        final cellInverse = CharAttributeUtils.isInverse(attr);

        final fgColorAttr = CharAttributeUtils.getFgColor(attr);
        final bgColorAttr = CharAttributeUtils.getBgColor(attr);
        //TODO: Theme
        var fgColor = _getColor(
            fgColorAttr,
            TerminalThemes.defaultTheme.foreground,
            TerminalThemes.defaultTheme);
        //TODO: Theme
        var bgColor = _getColor(
            bgColorAttr,
            TerminalThemes.defaultTheme.background,
            TerminalThemes.defaultTheme);

        // background color is already painted with opacity by the Container of
        // TerminalPainter so wo don't need to fallback to
        // terminal.theme.background here.
        final effectiveBgColorAttr = cellInverse ? fgColorAttr : bgColorAttr;
        final effectiveBgColor = cellInverse ? fgColor : bgColor;

        if (effectiveBgColorAttr == Renderer.DefaultColor) {
          continue;
        }

        final paint = Paint()..color = Color(effectiveBgColor.value);
        canvas.drawRect(
          Rect.fromLTWH(offsetX, offsetY, effectWidth, effectHeight),
          paint,
        );
      }
    }
  }

  void _paintSelection(Canvas canvas) {
    if (!selection.isActive) {
      return;
    }
    for (var y = 0; y < terminal.rows; y++) {
      final offsetY = y * charSize.cellHeight;

      final absoluteY = terminal.buffer.yBase + y;

      for (var x = 0; x < terminal.cols; x++) {
        var cellCount = 0;

        while (selection.contains(Point<int>(x + cellCount, absoluteY)) &&
            x + cellCount < terminal.cols) {
          cellCount++;
        }

        if (cellCount == 0) {
          continue;
        }

        final offsetX = x * charSize.cellWidth;
        final effectWidth = cellCount * charSize.cellWidth;
        final effectHeight = charSize.cellHeight;

        final paint = Paint()..color = Colors.white.withOpacity(0.3);
        canvas.drawRect(
          Rect.fromLTWH(offsetX, offsetY, effectWidth, effectHeight),
          paint,
        );

        x += cellCount;
      }
    }
  }

  void _paintText(Canvas canvas) {
    final lines = terminal.buffer.lines;

    for (var i = 0; i < terminal.rows; i++) {
      final line = lines[terminal.buffer.yDisp + i];
      if (line == null) {
        continue;
      }
      final offsetY = i * charSize.cellHeight;
      final cellCount = min(terminal.cols, line.length);

      for (var i = 0; i < cellCount; i++) {
        final cell = line[i];

        if (cell.width == 0) {
          continue;
        }

        final offsetX = i * charSize.cellWidth;
        _paintCell(canvas, cell, offsetX, offsetY);
      }
    }
  }

  void _paintCell(
      Canvas canvas, CharData cell, double offsetX, double offsetY) {
    final attr = cell.attribute;

    final cellInvisible = CharAttributeUtils.isInvisible(attr);

    if (cell.code == 0 || cellInvisible) {
      return;
    }

    final cellHash = hashValues(cell.code, attr);
    var tp = textLayoutCache.getLayoutFromCache(cellHash);
    if (tp != null) {
      tp.paint(canvas, Offset(offsetX, offsetY));
      return;
    }

    final cellInverse = CharAttributeUtils.isInverse(attr);
    final fgColorAttr = CharAttributeUtils.getFgColor(attr);
    final bgColorAttr = CharAttributeUtils.getBgColor(attr);
    //TODO: Theme
    var fgColor = _getColor(fgColorAttr, TerminalThemes.defaultTheme.foreground,
        TerminalThemes.defaultTheme);
    //TODO: Theme
    var bgColor = _getColor(bgColorAttr, TerminalThemes.defaultTheme.background,
        TerminalThemes.defaultTheme);

    final effectiveColor = cellInverse ? bgColor : fgColor;

    var color = Color(effectiveColor.value);

    final cellDim = CharAttributeUtils.isDim(attr);
    final cellBold = CharAttributeUtils.isBold(attr);
    final cellItalic = CharAttributeUtils.isItalic(attr);
    final cellUnderline = CharAttributeUtils.isUnderline(attr);

    if (cellDim) {
      color = color.withOpacity(0.5);
    }

    final style = (view.style.textStyleProvider != null)
        ? view.style.textStyleProvider!(
            color: color,
            fontWeight: cellBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: cellItalic ? FontStyle.italic : FontStyle.normal,
            fontSize: view.style.fontSize,
            decoration:
                cellUnderline ? TextDecoration.underline : TextDecoration.none,
          )
        : TextStyle(
            color: color,
            fontWeight: cellBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: cellItalic ? FontStyle.italic : FontStyle.normal,
            fontSize: view.style.fontSize,
            decoration:
                cellUnderline ? TextDecoration.underline : TextDecoration.none,
            fontFamily: 'monospace',
            fontFamilyFallback: view.style.fontFamily,
          );

    final span = TextSpan(
      text: String.fromCharCode(cell.code),
      // text: codePointCache.getOrConstruct(cell.codePoint),
      style: style,
    );

    // final tp = textLayoutCache.getOrPerformLayout(span);
    tp = textLayoutCache.performAndCacheLayout(span, cellHash);

    tp.paint(canvas, Offset(offsetX, offsetY));
  }

  void _paintCursor(Canvas canvas) {
    final screenCursorY = terminal.buffer.y + terminal.buffer.yBase;
    if (screenCursorY < 0 || screenCursorY >= terminal.rows) {
      return;
    }

    final char = terminal.buffer.lines[terminal.buffer.y]?[terminal.buffer.x];
    final width =
        char != null ? charSize.cellWidth * char.width : charSize.cellWidth;

    final offsetX = charSize.cellWidth * terminal.buffer.x;
    final offsetY = charSize.cellHeight * screenCursorY;
    //TODO: Theme
    final paint = Paint()
      ..color = Color(TerminalThemes.defaultTheme.cursor.value)
      ..strokeWidth = focused ? 0.0 : 1.0
      ..style = focused ? PaintingStyle.fill : PaintingStyle.stroke;
    canvas.drawRect(
        Rect.fromLTWH(offsetX, offsetY, width, charSize.cellHeight), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    /// paint only when the terminal has changed since last paint.
    return terminal.getUpdateRange() != null;
  }
}
