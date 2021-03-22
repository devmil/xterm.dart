import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:xterm/frontend/char_size.dart';
import 'package:xterm/frontend/helpers.dart';
import 'package:xterm/frontend/input_behavior.dart';
import 'package:xterm/frontend/input_behaviors.dart';
import 'package:xterm/frontend/input_listener.dart';
import 'package:xterm/frontend/oscillator.dart';
import 'package:xterm/frontend/cache.dart';
import 'package:xterm/mouse/position.dart';
import 'package:xterm/terminal/terminal_isolate.dart';
import 'package:xterm/theme/terminal_style.dart';
import 'package:xterm/utli/hash_values.dart';

typedef TerminalResizeHandler = void Function(int width, int height);

class TerminalView extends StatefulWidget {
  TerminalView({
    Key? key,
    required this.terminal,
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

  final TerminalIsolate terminal;
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
  /// blinking cursor and blinking character
  final oscillator = Oscillator.ms(600);

  bool get focused {
    return widget.focusNode.hasFocus;
  }

  int? _lastTerminalWidth;
  int? _lastTerminalHeight;

  late CellSize _cellSize;

  void onTerminalChange() {
    final currentScrollExtent =
        _cellSize.cellHeight * widget.terminal.lastState!.scrollOffsetFromTop;

    widget.scrollController.jumpTo(currentScrollExtent);

    if (mounted) {
      setState(() {});
    }
  }

  // listen to oscillator to update mouse blink etc.
  // void onTick() {
  //   widget.terminal.refresh();
  // }

  @override
  void initState() {
    // oscillator.start();
    // oscillator.addListener(onTick);

    // measureCellSize is expensive so we cache the result.
    _cellSize = widget.measureCellSize();

    widget.terminal.addListener(onTerminalChange);

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

                var bufferHeight = 80;
                if (widget.terminal.lastState != null) {
                  bufferHeight = widget.terminal.lastState!.bufferHeight;
                }

                final maxScrollExtent = math.max(
                    0.0,
                    _cellSize.cellHeight * bufferHeight -
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
        if (widget.terminal.lastState == null) {
          return;
        }
        if (widget.terminal.lastState!.selection.isEmpty) {
          InputListener.of(context)!.requestKeyboard();
        } else {
          widget.terminal.clearSelection();
        }
        final pos = detail.localPosition;
        final offset = getMouseOffset(pos.dx, pos.dy);
        widget.terminal.onMouseTap(offset);
        widget.terminal.refresh();
      },
      onPanStart: (detail) {
        final pos = detail.localPosition;
        final offset = getMouseOffset(pos.dx, pos.dy);
        widget.terminal.onPanStart(offset);
        widget.terminal.refresh();
      },
      onPanUpdate: (detail) {
        final pos = detail.localPosition;
        final offset = getMouseOffset(pos.dx, pos.dy);
        widget.terminal.onPanUpdate(offset);
        widget.terminal.refresh();
      },
      child: Container(
        constraints: BoxConstraints.expand(),
        color: Color(widget.terminal.theme.background.value)
            .withOpacity(widget.opacity),
        child: CustomPaint(
          painter: TerminalPainter(
            terminal: widget.terminal,
            view: widget,
            oscillator: oscillator,
            focused: focused,
            charSize: _cellSize,
          ),
        ),
      ),
    );
  }

  Position getMouseOffset(double px, double py) {
    final col = (px / _cellSize.cellWidth).floor();
    final row = (py / _cellSize.cellHeight).floor();

    final x = col;
    final y = widget.terminal.convertViewLineToRawLine(row) -
        widget.terminal.lastState!.scrollOffsetFromBottom;

    return Position(x, y);
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

  void onKeyStroke(RawKeyEvent event) {
    widget.inputBehavior.onKeyStroke(event, widget.terminal);
    widget.terminal.setScrollOffsetFromBottom(0);
  }

  void onFocus(bool focused) {
    SchedulerBinding.instance!.addPostFrameCallback((_) {
      widget.terminal.refresh();
    });
  }

  void onAction(TextInputAction action) {
    widget.inputBehavior.onAction(action, widget.terminal);
  }

  // synchronize flutter scroll offset to terminal
  void onScroll(double offset) {
    final topOffset = (offset / _cellSize.cellHeight).ceil();
    final bottomOffset = widget.terminal.lastState!.invisibleHeight - topOffset;

    widget.terminal.setScrollOffsetFromBottom(bottomOffset);
  }
}

class TerminalPainter extends CustomPainter {
  TerminalPainter({
    required this.terminal,
    required this.view,
    required this.oscillator,
    required this.focused,
    required this.charSize,
  });

  final TerminalIsolate terminal;
  final TerminalView view;
  final Oscillator oscillator;
  final bool focused;
  final CellSize charSize;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas);

    // if (oscillator.value) {
    // }

    if (terminal.lastState == null) {
      return;
    }

    if (terminal.lastState!.showCursor) {
      _paintCursor(canvas);
    }

    _paintText(canvas);

    _paintSelection(canvas);
  }

  void _paintBackground(Canvas canvas) {
    if (terminal.lastState == null) {
      return;
    }
    final lines = terminal.lastState!.visibleLines;
    lines.addUsage();

    for (var y = 0; y < terminal.lastState!.viewHeight; y++) {
      final offsetY = y * charSize.cellHeight;
      final cellCount = terminal.lastState!.viewWidth;

      for (var x = 0; x < cellCount; x++) {
        final cellWidth = lines.widthAt(x, y);
        if (!lines.hasData(x, y) || cellWidth == 0) {
          continue;
        }

        final offsetX = x * charSize.cellWidth;
        final effectWidth = charSize.cellWidth * cellWidth + 1;
        final effectHeight = charSize.cellHeight + 1;

        final cellInverse = lines.isInverseAt(x, y);
        final cellFgColor = lines.fgColorAt(x, y);
        final cellBgColor = lines.bgColorAt(x, y);

        final bgColor = cellInverse ? cellFgColor : cellBgColor;

        if (bgColor == null) {
          continue;
        }

        final paint = Paint()..color = Color(bgColor.value);
        canvas.drawRect(
          Rect.fromLTWH(offsetX, offsetY, effectWidth, effectHeight),
          paint,
        );
      }
    }
    lines.removeUsage();
  }

  void _paintSelection(Canvas canvas) {
    if (terminal.lastState == null) {
      return;
    }
    for (var y = 0; y < terminal.lastState!.viewHeight; y++) {
      final offsetY = y * charSize.cellHeight;
      final absoluteY = terminal.convertViewLineToRawLine(y) -
          terminal.lastState!.scrollOffsetFromBottom;

      for (var x = 0; x < terminal.lastState!.viewWidth; x++) {
        var cellCount = 0;

        while (terminal.lastState!.selection
                .contains(Position(x + cellCount, absoluteY)) &&
            x + cellCount < terminal.lastState!.viewWidth) {
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
    if (terminal.lastState == null) {
      return;
    }
    final lines = terminal.lastState!.visibleLines;
    lines.addUsage();

    for (var y = 0; y < terminal.lastState!.viewHeight; y++) {
      final offsetY = y * charSize.cellHeight;
      final cellCount = terminal.lastState!.viewWidth;

      for (var x = 0; x < cellCount; x++) {
        final cellWidth = lines.widthAt(x, y);
        if (!lines.hasData(x, y) || cellWidth == 0) {
          continue;
        }

        final offsetX = x * charSize.cellWidth;
        _paintCell(canvas, lines, x, y, offsetX, offsetY);
      }
    }
    lines.removeUsage();
  }

  void _paintCell(Canvas canvas, UiBufferLines lines, int x, int y,
      double offsetX, double offsetY) {
    final cellCodePoint = lines.codePointAt(x, y);
    final cellInvisible = lines.isInvisibleAt(x, y);

    if (cellCodePoint == 0 || cellInvisible) {
      return;
    }

    final cellFgColor = lines.fgColorAt(x, y);
    final cellBgColor = lines.bgColorAt(x, y);
    final cellFlags = lines.flagsAt(x, y);

    final cellHash =
        hashValues(cellCodePoint, cellFgColor, cellBgColor, cellFlags);
    var tp = textLayoutCache.getLayoutFromCache(cellHash);
    if (tp != null) {
      tp.paint(canvas, Offset(offsetX, offsetY));
      return;
    }

    final cellInverse = lines.isInverseAt(x, y);
    final cellFaint = lines.isFaintAt(x, y);
    final cellBold = lines.isBoldAt(x, y);
    final cellItalic = lines.isItalicAt(x, y);
    final cellUnderline = lines.isUnderlineAt(x, y);

    final cellColor = cellInverse
        ? cellBgColor ?? terminal.theme.background
        : cellFgColor ?? terminal.theme.foreground;

    var color = Color(cellColor.value);

    if (cellFaint) {
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
      text: String.fromCharCode(cellCodePoint),
      // text: codePointCache.getOrConstruct(cell.codePoint),
      style: style,
    );

    // final tp = textLayoutCache.getOrPerformLayout(span);
    tp = textLayoutCache.performAndCacheLayout(span, cellHash);

    tp.paint(canvas, Offset(offsetX, offsetY));
  }

  void _paintCursor(Canvas canvas) {
    if (terminal.lastState == null) {
      return;
    }
    final screenCursorY =
        terminal.lastState!.cursorY + terminal.lastState!.scrollOffset;
    if (screenCursorY < 0 || screenCursorY >= terminal.lastState!.viewHeight) {
      return;
    }

    final cellWidthUnderCursor = terminal.lastState!.cellWidthUnderCursor;
    final width = cellWidthUnderCursor != null
        ? charSize.cellWidth * cellWidthUnderCursor
        : charSize.cellWidth;

    final offsetX = charSize.cellWidth * terminal.lastState!.cursorX;
    final offsetY = charSize.cellHeight * screenCursorY;
    final paint = Paint()
      ..color = Color(terminal.theme.cursor.value)
      ..strokeWidth = focused ? 0.0 : 1.0
      ..style = focused ? PaintingStyle.fill : PaintingStyle.stroke;
    canvas.drawRect(
        Rect.fromLTWH(offsetX, offsetY, width, charSize.cellHeight), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    /// paint only when the terminal has changed since last paint.
    if (terminal.lastState == null) {
      return false;
    }
    if (terminal.lastState!.consumed) {
      return false;
    }
    terminal.lastState!.consumed = true;
    return true;
  }
}
