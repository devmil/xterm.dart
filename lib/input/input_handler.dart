import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:xterm/buffer/char_attribute_utils.dart';
import 'package:xterm/buffer/char_data.dart';
import 'package:xterm/input/decrqss.dart';
import 'package:xterm/input/escape_sequence_parser.dart';
import 'package:xterm/input/reading_buffer.dart';
import 'package:xterm/input/terminal_command_extensions.dart';
import 'package:xterm/input/terminal_status_command_extensions.dart';
import 'package:xterm/input/terminal_buffer_manipulation_command_extensions.dart';
import 'package:xterm/input/terminal_mode_set_extensions.dart';
import 'package:xterm/terminal/char_sets.dart';
import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/terminal/terminal_options.dart';
import 'package:xterm/util/rune_utils.dart';

class InputHandler {
  ReadingBuffer _readingBuffer = ReadingBuffer();
  Terminal _terminal;
  EscapeSequenceParser _parser = EscapeSequenceParser();
  final _utf8Decoder = Utf8Decoder();

  InputHandler(this._terminal) {
    _parser.setCsiHandlerFallback((String collect, List<int> pars, int flag) {
      _terminal.error('Unknown CSI code', [collect, pars, flag]);
    });
    _parser.setEscHandlerFallback((String collect, int flag) {
      _terminal.error('Unknown ESC code', [collect, flag]);
    });
    _parser.setExecuteHandlerFallback((code) {
      _terminal.error('Unknown EXECUTE code', [code]);
    });
    _parser.setOscHandlerFallback((int identifier, String data) {
      _terminal.error('Unknown OSC code', [identifier, data]);
    });

    // Print handler
    _parser.setPrintHandler(_print);
    _parser.printStateReset = _printStateReset;

    // CSI handler
    _parser.setCsiHandler('@', (pars, collect) => _insertChars(pars));
    _parser.setCsiHandler('A', (pars, collect) => _terminal.csiCUU(pars));
    _parser.setCsiHandler('B', (pars, collect) => _terminal.csiCUD(pars));
    _parser.setCsiHandler('C', (pars, collect) => _terminal.csiCUF(pars));
    _parser.setCsiHandler('D', (pars, collect) => _terminal.csiCUB(pars));
    _parser.setCsiHandler('E', (pars, collect) => _cursorNextLine(pars));
    _parser.setCsiHandler('F', (pars, collect) => _cursorPrecedingLine(pars));
    _parser.setCsiHandler('G', (pars, collect) => _terminal.csiCHA(pars));
    _parser.setCsiHandler('H', (pars, collect) => _terminal.csiCUP(pars));
    _parser.setCsiHandler('I', (pars, collect) => _cursorForwardTab(pars));
    _parser.setCsiHandler('J', (pars, collect) => _eraseInDisplay(pars));
    _parser.setCsiHandler('K', (pars, collect) => _eraseInLine(pars));
    _parser.setCsiHandler('L', (pars, collect) => _insertLines(pars));
    _parser.setCsiHandler('M', (pars, collect) => _terminal.csiDL(pars));
    _parser.setCsiHandler('P', (pars, collect) => _terminal.csiDCH(pars));
    _parser.setCsiHandler('S', (pars, collect) => _scrollUp(pars));
    _parser.setCsiHandler('T', (pars, collect) => _scrollDown(pars));
    _parser.setCsiHandler('X', (pars, collect) => _eraseChars(pars));
    _parser.setCsiHandler('Z', (pars, collect) => _terminal.csiCBT(pars));
    _parser.setCsiHandler('`', (pars, collect) => _charPosAbsolute(pars));
    _parser.setCsiHandler('a', (pars, collect) => _hPositionRelative(pars));
    _parser.setCsiHandler(
        'b', (pars, collect) => _repeatPrecedingCharacter(pars));
    _parser.setCsiHandler(
        'c', (pars, collect) => _terminal.csiDA1(pars, collect));
    _parser.setCsiHandler('d', (pars, collect) => _linePosAbsolute(pars));
    _parser.setCsiHandler('e', (pars, collect) => _vPositionRelative(pars));
    _parser.setCsiHandler('f', (pars, collect) => _hVPosition(pars));
    _parser.setCsiHandler('g', (pars, collect) => _tabClear(pars));
    _parser.setCsiHandler('h', (pars, collect) => _setMode(pars, collect));
    _parser.setCsiHandler('l', (pars, collect) => _resetMode(pars, collect));
    _parser.setCsiHandler('m', (pars, collect) => _charAttributes(pars));
    _parser.setCsiHandler(
        'n', (pars, collect) => _terminal.csiDSR(pars, collect));
    _parser.setCsiHandler('p', (pars, collect) {
      switch (collect) {
        case '!':
          _terminal.softReset();
          break;
        case '\'':
          //TODO: SetConformanceLevel (pars, collect);
          break;
        default:
          _terminal.error('Unknown CSI code', [collect, pars, 'p']);
          break;
      }
    });
    _parser.setCsiHandler(
        'q', (pars, collect) => _setCursorStyle(pars, collect));
    _parser.setCsiHandler('r', (pars, collect) {
      if (collect == '') {
        _terminal.csiDECSTBM(pars);
      }
    });
    _parser.setCsiHandler('s', (pars, collect) {
      // 'CSI s' is overloaded, can mean save cursor, but also set the margins with DECSLRM
      if (_terminal.marginMode) {
        this._terminal.csiDECSLRM(pars);
      } else {
        _terminal.saveCursor();
      }
    });
    _parser.setCsiHandler('t', (pars, collect) => _terminal.csiDISPATCH(pars));
    _parser.setCsiHandler('u', (pars, collect) => _terminal.restoreCursor());
    _parser.setCsiHandler(
        'v', (pars, collect) => _terminal.csiDECCRA(pars, collect));
    _parser.setCsiHandler('y', (pars, collect) => _terminal.csiDECRQCRA(pars));
    _parser.setCsiHandler('x', (pars, collect) {
      switch (collect) {
        case '\$':
          _terminal.csiDECFRA(pars);
          break;
        default:
          _terminal.error('Unknown CSI code', [collect, pars, 'x']);
          break;
      }
    });
    _parser.setCsiHandler('z', (pars, collect) {
      switch (collect) {
        case '\$':
          _terminal.csiDECERA(pars);
          break;
        case '\'':
          // TODO: Enable Locator Reporting (DECELR)
          // Enable Locator Reporting (DECELR).
          // Valid values for the first parameter:
          //   Ps = 0  ⇒  Locator disabled (default).
          //   Ps = 1  ⇒  Locator enabled.
          //   Ps = 2  ⇒  Locator enabled for one report, then disabled.
          // The second parameter specifies the coordinate unit for locator
          // reports.
          // Valid values for the second parameter:
          //   Pu = 0  or omitted ⇒  default to character cells.
          //   Pu = 1  ⇐  device physical pixels.
          //   Pu = 2  ⇐  character cells.
          break;
        default:
          _terminal.error('Unknown CSI code', [collect, pars, 'z']);
          break;
      }
    });
    _parser.setCsiHandler('{', (pars, collect) {
      switch (collect) {
        case '\$':
          _terminal.csiDECSERA(pars);
          break;
        default:
          _terminal.error('Unknown CSI code', [collect, pars, '{']);
          break;
      }
    });
    _parser.setCsiHandler('}', (pars, collect) {
      switch (collect) {
        case '\'':
          _terminal.csiDECIC(pars);
          break;
        default:
          _terminal.error('Unknown CSI code', [collect, pars, '}']);
          break;
      }
    });
    _parser.setCsiHandler('~', (pars, collect) => _terminal.csiDECDC(pars));

    // Execute Handler
    _parser.setExecuteHandler(7, _terminal.bell);
    _parser.setExecuteHandler(10, _terminal.lineFeed);
    _parser.setExecuteHandler(
        11,
        _terminal
            .lineFeedBasic); // VT Vertical Tab - ignores auto-new-line behavior in ConvertEOL
    _parser.setExecuteHandler(12, _terminal.lineFeedBasic);
    _parser.setExecuteHandler(13, _terminal.carriageReturn);
    _parser.setExecuteHandler(8, _terminal.backspace);
    _parser.setExecuteHandler(9, _tab);
    _parser.setExecuteHandler(14, _shiftOut);
    _parser.setExecuteHandler(15, _shiftIn);
    // Comment in original FIXME:   What do to with missing? Old code just added those to print.

    // some C1 control codes - FIXME: should those be enabled by default?
    _parser.setExecuteHandler(0x84 /* Index */, () => _terminal.index());
    _parser.setExecuteHandler(0x85 /* Next Line */, _terminal.nextLine);
    _parser.setExecuteHandler(0x88 /* Horizontal Tabulation Set */, _tabSet);

    //
    // OSC handler
    //
    //   0 - icon name + title
    _parser.setOscHandler(0, _setTitleAndIcon);
    //   1 - icon name
    _parser.setOscHandler(1, _setIconTitle);
    //   2 - title
    _parser.setOscHandler(2, _setTitle);
    //   3 - set property X in the form 'prop=value'
    //   4 - Change Color Number()
    //   5 - Change Special Color Number
    //   6 - Enable/disable Special Color Number c
    //   7 - current directory? (not in xterm spec, see https://gitlab.com/gnachman/iterm2/issues/3939)
    //  10 - Change VT100 text foreground color to Pt.
    //  11 - Change VT100 text background color to Pt.
    //  12 - Change text cursor color to Pt.
    //  13 - Change mouse foreground color to Pt.
    //  14 - Change mouse background color to Pt.
    //  15 - Change Tektronix foreground color to Pt.
    //  16 - Change Tektronix background color to Pt.
    //  17 - Change highlight background color to Pt.
    //  18 - Change Tektronix cursor color to Pt.
    //  19 - Change highlight foreground color to Pt.
    //  46 - Change Log File to Pt.
    //  50 - Set Font to Pt.
    //  51 - reserved for Emacs shell.
    //  52 - Manipulate Selection Data.
    // 104 ; c - Reset Color Number c.
    // 105 ; c - Reset Special Color Number c.
    // 106 ; c; f - Enable/disable Special Color Number c.
    // 110 - Reset VT100 text foreground color.
    // 111 - Reset VT100 text background color.
    // 112 - Reset text cursor color.
    // 113 - Reset mouse foreground color.
    // 114 - Reset mouse background color.
    // 115 - Reset Tektronix foreground color.
    // 116 - Reset Tektronix background color.

    //
    // ESC handlers
    //
    _parser.setEscHandler('7', (c, f) => _terminal.saveCursor());
    _parser.setEscHandler('8', (c, f) => _terminal.restoreCursor());
    _parser.setEscHandler('D', (c, f) => _terminal.index());
    _parser.setEscHandler('E', (c, b) => _terminal.nextLine());
    _parser.setEscHandler('H', (c, f) => _tabSet());
    _parser.setEscHandler('M', (c, f) => _reverseIndex());
    _parser.setEscHandler('=', (c, f) => _keypadApplicationMode());
    _parser.setEscHandler('>', (c, f) => _keypadNumericMode());
    _parser.setEscHandler('c', (c, f) => _reset());
    _parser.setEscHandler('n', (c, f) => _setgLevel(2));
    _parser.setEscHandler('o', (c, f) => _setgLevel(3));
    _parser.setEscHandler('|', (c, f) => _setgLevel(3));
    _parser.setEscHandler('}', (c, f) => _setgLevel(2));
    _parser.setEscHandler('~', (c, f) => _setgLevel(1));
    _parser.setEscHandler('%@', (c, f) => _selectDefaultCharset());
    _parser.setEscHandler('%G', (c, f) => _selectDefaultCharset());
    _parser.setEscHandler('#3', (c, f) => _setDoubleHeightTop()); // dhtop
    _parser.setEscHandler('#4', (c, f) => _setDoubleHeightBottom()); // dhbot
    _parser.setEscHandler('#5', (c, f) => _singleWidthSingleHeight()); // swsh
    _parser.setEscHandler('#6', (c, f) => _doubleWidthSingleHeight()); // dwsh
    for (var bflag in CharSets.all.keys) {
      final flag = String.fromCharCode(bflag);
      _parser.setEscHandler(
          '(' + flag, (code, f) => _selectCharset('(' + flag));
      _parser.setEscHandler(
          ')' + flag, (code, f) => _selectCharset(')' + flag));
      _parser.setEscHandler(
          '*' + flag, (code, f) => _selectCharset('*' + flag));
      _parser.setEscHandler(
          '+' + flag, (code, f) => _selectCharset('+' + flag));
      _parser.setEscHandler(
          '-' + flag, (code, f) => _selectCharset('-' + flag));
      _parser.setEscHandler(
          '.' + flag, (code, f) => _selectCharset('.' + flag));
      _parser.setEscHandler('/' + flag,
          (code, f) => _selectCharset('/' + flag)); // TODO: supported?
    }

    // Error handler
    _parser.setErrorHandler((state) {
      _terminal.error('Parsing error, state: ', [state]);
      return state;
    });

    // DCS Handler
    _parser.setDcsHandler('\$q', DECRQSS(_terminal));
  }

  void parse(Uint8List data, [int length = -1]) {
    if (length == -1) {
      length = data.length;
    } else {
      data = Uint8List.view(data.buffer, 0, length);
    }

    _parser.parse(data);
  }

  void _insertLines(List<int> pars) {
    var p = max(pars.length == 0 ? 1 : pars[0], 1);
    var buffer = _terminal.buffer;
    var row = buffer.y + buffer.yBase;

    var scrollBottomRowsOffset = _terminal.rows - 1 - buffer.scrollBottom;
    var scrollBottomAbsolute =
        _terminal.rows - 1 + buffer.yBase - scrollBottomRowsOffset + 1;

    var eraseAttr = _terminal.eraseAttr();
    while (p-- != 0) {
      // test: echo -e '\e[44m\e[1L\e[0m'
      // blankLine(true) - xterm/linux behavior
      buffer.lines.splice(scrollBottomAbsolute - 1, 1, []);
      var newLine = buffer.getBlankLine(eraseAttr);
      buffer.lines.splice(row, 0, [newLine]);
    }

    // this.maxRange();
    _terminal.updateRange(buffer.y);
    _terminal.updateRange(buffer.scrollBottom);
  }

  //
  // ESC ( C
  //   Designate G0 Character Set, VT100, ISO 2022.
  // ESC ) C
  //   Designate G1 Character Set (ISO 2022, VT100).
  // ESC * C
  //   Designate G2 Character Set (ISO 2022, VT220).
  // ESC + C
  //   Designate G3 Character Set (ISO 2022, VT220).
  // ESC - C
  //   Designate G1 Character Set (VT300).
  // ESC . C
  //   Designate G2 Character Set (VT300).
  // ESC / C
  //   Designate G3 Character Set (VT300). C = A  -> ISO Latin-1 Supplemental. - Supported?
  //
  void _selectCharset(String p) {
    if (p.length != 2) _selectDefaultCharset();
    int ch;

    final charset = CharSets.all[p[1].runes.first];

    switch (p[0]) {
      case '(':
        ch = 0;
        break;
      case ')':
      case '-':
        ch = 1;
        break;
      case '*':
      case '.':
        ch = 2;
        break;
      case '+':
        ch = 3;
        break;
      default:
        // includes '/' -> unsupported? (MIGUEL TODO)
        return;
    }
    _terminal.setgCharset(ch, charset!);
  }

  //
  // ESC # NUMBER
  //
  void _doubleWidthSingleHeight() {}

  //
  // dhtop
  //
  void _setDoubleHeightTop() {}

  // dhbot
  void _setDoubleHeightBottom() {} // dhbot

  //
  // swsh
  //
  void _singleWidthSingleHeight() {}

  //
  // ESC % @
  // ESC % G
  //   Select default character set. UTF-8 is not supported (string are unicode anyways)
  //   therefore ESC % G does the same.
  //
  void _selectDefaultCharset() {
    _terminal.setgLevel(0);
    _terminal.setgCharset(0, CharSets.Default!);
  }

  //
  // ESC n
  // ESC o
  // ESC |
  // ESC }
  // ESC ~
  //   DEC mnemonic: LS (https://vt100.net/docs/vt510-rm/LS.html)
  //   When you use a locking shift, the character set remains in GL or GR until
  //   you use another locking shift. (partly supported)
  //
  void _setgLevel(int n) {
    _terminal.setgLevel(n);
  }

  //
  // ESC c
  //   DEC mnemonic: RIS (https://vt100.net/docs/vt510-rm/RIS.html)
  //   Reset to initial state.
  //
  void _reset() {
    _parser.reset();
    _terminal.reset();
  }

  //
  // ESC >
  //   DEC mnemonic: DECKPNM (https://vt100.net/docs/vt510-rm/DECKPNM.html)
  //   Enables the keypad to send numeric characters to the host.
  //
  void _keypadNumericMode() {
    _terminal.applicationKeypad = false;
    _terminal.syncScrollArea();
  }

  //
  // ESC =
  //   DEC mnemonic: DECKPAM (https://vt100.net/docs/vt510-rm/DECKPAM.html)
  //   Enables the numeric keypad to send application sequences to the host.
  //
  void _keypadApplicationMode() {
    _terminal.applicationKeypad = true;
    _terminal.syncScrollArea();
  }

  //
  // ESC M
  // C1.RI
  //   DEC mnemonic: HTS
  //   Moves the cursor up one line in the same column. If the cursor is at the top margin,
  //   the page scrolls down.
  //
  void _reverseIndex() {
    _terminal.reverseIndex();
  }

  /// <summary>
  /// OSC 0; <data> ST (set window and icon title)
  ///   Proxy to set window title.
  /// </summary>
  /// <param name="data"></param>
  void _setTitleAndIcon(String? data) {
    _terminal.setTitle(data ?? '');
    _terminal.setIconTitle(data ?? '');
  }

  /// <summary>
  /// OSC 2; <data> ST (set window title)
  ///   Proxy to set window title.
  /// </summary>
  /// <param name="data"></param>
  void _setTitle(String? data) {
    _terminal.setTitle(data ?? '');
  }

  /// <summary>
  /// OSC 1; <data> ST (set window title)
  ///   Proxy to set icon title.
  /// </summary>
  void _setIconTitle(String? data) {
    _terminal.setIconTitle(data ?? '');
  }

  //
  // ESC H
  // C1.HTS
  //   DEC mnemonic: HTS (https://vt100.net/docs/vt510-rm/HTS.html)
  //   Sets a horizontal tab stop at the column position indicated by
  //   the value of the active column when the _terminal receives an HTS.
  //
  void _tabSet() {
    _terminal.buffer.tabSet(_terminal.buffer.x);
  }

  // SI
  // ShiftIn (Control-O) Switch to standard character set.  This invokes the G0 character set
  void _shiftIn() {
    _terminal.setgLevel(0);
  }

  // SO
  // ShiftOut (Control-N) Switch to alternate character set.  This invokes the G1 character set
  void _shiftOut() {
    _terminal.setgLevel(1);
  }

  //
  // Horizontal tab (Control-I)
  //
  void _tab() {
    var originalX = _terminal.buffer.x;
    _terminal.buffer.x = _terminal.buffer.nextTabStop();
    if (_terminal.options.screenReaderMode)
      _terminal.emitA11yTab(_terminal.buffer.x - originalX);
  }

  //
  // Helper method to erase cells in a _terminal row.
  // The cell gets replaced with the eraseChar of the _terminal.
  // @param y row index
  // @param start first cell index to be erased
  // @param end   end - 1 is last erased cell
  //
  void _eraseInBufferLine(int y, int start, int end, [bool clearWrap = false]) {
    var line = _terminal.buffer.lines[_terminal.buffer.yBase + y];
    var cd = new CharData(_terminal.eraseAttr());
    line!.replaceCells(start, end, cd);
    if (clearWrap) line.isWrapped = false;
  }

  //
  // Helper method to reset cells in a _terminal row.
  // The cell gets replaced with the eraseChar of the _terminal and the isWrapped property is set to false.
  // @param y row index
  //
  void _resetBufferLine(int y) {
    _eraseInBufferLine(y, 0, _terminal.cols, true);
  }

  //
  // CSI Ps SP q  Set cursor style (DECSCUSR, VT520).
  //   Ps = 0  -> blinking block.
  //   Ps = 1  -> blinking block (default).
  //   Ps = 2  -> steady block.
  //   Ps = 3  -> blinking underline.
  //   Ps = 4  -> steady underline.
  //   Ps = 5  -> blinking bar (xterm).
  //   Ps = 6  -> steady bar (xterm).
  //
  void _setCursorStyle(List<int> pars, String collect) {
    if (collect != " ") return;

    var p = max(pars.length == 0 ? 1 : pars[0], 1);
    switch (p) {
      case 1:
        _terminal.setCursorStyle(CursorStyle.BlinkBlock);
        break;
      case 2:
        _terminal.setCursorStyle(CursorStyle.SteadyBlock);
        break;
      case 3:
        _terminal.setCursorStyle(CursorStyle.BlinkUnderline);
        break;
      case 4:
        _terminal.setCursorStyle(CursorStyle.SteadyUnderline);
        break;
      case 5:
        _terminal.setCursorStyle(CursorStyle.BlinkingBar);
        break;
      case 6:
        _terminal.setCursorStyle(CursorStyle.SteadyBar);
        break;
    }
  }

  //
  // CSI Pm m  Character Attributes (SGR).
  //     Ps = 0  -> Normal (default).
  //     Ps = 1  -> Bold.
  //     Ps = 2  -> Faint, decreased intensity (ISO 6429).
  //     Ps = 4  -> Underlined.
  //     Ps = 5  -> Blink (appears as Bold).
  //     Ps = 7  -> Inverse.
  //     Ps = 8  -> Invisible, i.e., hidden (VT300).
  //     Ps = 2 2  -> Normal (neither bold nor faint).
  //     Ps = 2 4  -> Not underlined.
  //     Ps = 2 5  -> Steady (not blinking).
  //     Ps = 2 7  -> Positive (not inverse).
  //     Ps = 2 8  -> Visible, i.e., not hidden (VT300).
  //     Ps = 3 0  -> Set foreground color to Black.
  //     Ps = 3 1  -> Set foreground color to Red.
  //     Ps = 3 2  -> Set foreground color to Green.
  //     Ps = 3 3  -> Set foreground color to Yellow.
  //     Ps = 3 4  -> Set foreground color to Blue.
  //     Ps = 3 5  -> Set foreground color to Magenta.
  //     Ps = 3 6  -> Set foreground color to Cyan.
  //     Ps = 3 7  -> Set foreground color to White.
  //     Ps = 3 9  -> Set foreground color to default (original).
  //     Ps = 4 0  -> Set background color to Black.
  //     Ps = 4 1  -> Set background color to Red.
  //     Ps = 4 2  -> Set background color to Green.
  //     Ps = 4 3  -> Set background color to Yellow.
  //     Ps = 4 4  -> Set background color to Blue.
  //     Ps = 4 5  -> Set background color to Magenta.
  //     Ps = 4 6  -> Set background color to Cyan.
  //     Ps = 4 7  -> Set background color to White.
  //     Ps = 4 9  -> Set background color to default (original).
  //
  //   If 16-color support is compiled, the following apply.  Assume
  //   that xterm's resources are set so that the ISO color codes are
  //   the first 8 of a set of 16.  Then the aixterm colors are the
  //   bright versions of the ISO colors:
  //     Ps = 9 0  -> Set foreground color to Black.
  //     Ps = 9 1  -> Set foreground color to Red.
  //     Ps = 9 2  -> Set foreground color to Green.
  //     Ps = 9 3  -> Set foreground color to Yellow.
  //     Ps = 9 4  -> Set foreground color to Blue.
  //     Ps = 9 5  -> Set foreground color to Magenta.
  //     Ps = 9 6  -> Set foreground color to Cyan.
  //     Ps = 9 7  -> Set foreground color to White.
  //     Ps = 1 0 0  -> Set background color to Black.
  //     Ps = 1 0 1  -> Set background color to Red.
  //     Ps = 1 0 2  -> Set background color to Green.
  //     Ps = 1 0 3  -> Set background color to Yellow.
  //     Ps = 1 0 4  -> Set background color to Blue.
  //     Ps = 1 0 5  -> Set background color to Magenta.
  //     Ps = 1 0 6  -> Set background color to Cyan.
  //     Ps = 1 0 7  -> Set background color to White.
  //
  //   If xterm is compiled with the 16-color support disabled, it
  //   supports the following, from rxvt:
  //     Ps = 1 0 0  -> Set foreground and background color to
  //     default.
  //
  //   If 88- or 256-color support is compiled, the following apply.
  //     Ps = 3 8  ; 5  ; Ps -> Set foreground color to the second
  //     Ps.
  //     Ps = 4 8  ; 5  ; Ps -> Set background color to the second
  //     Ps.
  //
  void _charAttributes(List<int> pars) {
    // Optimize a single SGR0.
    if (pars.length == 1 && pars[0] == 0) {
      _terminal.curAttr = CharData.DefaultAttr;
      return;
    }

    var parCount = pars.length;
    var flags = (_terminal.curAttr >> 18);
    var fg = (_terminal.curAttr >> 9) & 0x1ff;
    var bg = _terminal.curAttr & 0x1ff;
    var def = CharData.DefaultAttr;

    for (var i = 0; i < parCount; i++) {
      int p = pars[i];
      if (p >= 30 && p <= 37) {
        // fg color 8
        fg = p - 30;
      } else if (p >= 40 && p <= 47) {
        // bg color 8
        bg = p - 40;
      } else if (p >= 90 && p <= 97) {
        // fg color 16
        p += 8;
        fg = p - 90;
      } else if (p >= 100 && p <= 107) {
        // bg color 16
        p += 8;
        bg = p - 100;
      } else if (p == 0) {
        // default

        flags = (def >> 18);
        fg = (def >> 9) & 0x1ff;
        bg = def & 0x1ff;
        // flags = 0;
        // fg = 0x1ff;
        // bg = 0x1ff;
      } else if (p == 1) {
        // bold text
        flags |= CharAttributeFlags.Bold.value;
      } else if (p == 3) {
        // italic text
        flags |= CharAttributeFlags.Italic.value;
      } else if (p == 4) {
        // underlined text
        flags |= CharAttributeFlags.Underline.value;
      } else if (p == 5) {
        // blink
        flags |= CharAttributeFlags.Blink.value;
      } else if (p == 7) {
        // inverse and positive
        // test with: echo -e '\e[31m\e[42mhello\e[7mworld\e[27mhi\e[m'
        flags |= CharAttributeFlags.Inverse.value;
      } else if (p == 8) {
        // invisible
        flags |= CharAttributeFlags.Invisible.value;
      } else if (p == 2) {
        // dimmed text
        flags |= CharAttributeFlags.Dim.value;
      } else if (p == 22) {
        // not bold nor faint
        flags &= ~CharAttributeFlags.Bold.value;
        flags &= ~CharAttributeFlags.Dim.value;
      } else if (p == 23) {
        // not italic
        flags &= ~CharAttributeFlags.Italic.value;
      } else if (p == 24) {
        // not underlined
        flags &= ~CharAttributeFlags.Underline.value;
      } else if (p == 25) {
        // not blink
        flags &= ~CharAttributeFlags.Blink.value;
      } else if (p == 27) {
        // not inverse
        flags &= ~CharAttributeFlags.Inverse.value;
      } else if (p == 28) {
        // not invisible
        flags &= ~CharAttributeFlags.Invisible.value;
      } else if (p == 39) {
        // reset fg
        fg = (CharData.DefaultAttr >> 9) & 0x1ff;
      } else if (p == 49) {
        // reset bg
        bg = CharData.DefaultAttr & 0x1ff;
      } else if (p == 38) {
        if (i + 1 < parCount) {
          // fg color 256
          if (pars[i + 1] == 2) {
            // Well this is a problem, if there are 3 arguments, expect R/G/B, if there are
            // more than 3, skip the first that would be the colorspace
            if (i + 5 < parCount) {
              i += 1;
            }
            if (i + 4 < parCount) {
              fg = _terminal.matchColor(
                  pars[i + 2] & 0xff, pars[i + 3] & 0xff, pars[i + 4] & 0xff);
              if (fg == -1) fg = 0x1ff;
            }
            // Given the historical disagreement that was caused by an ambiguous spec,
            // we eat all the remaining parameters.
            i = parCount;
          } else if (pars[i + 1] == 5) {
            if (i + 2 < parCount) {
              p = pars[i + 2] & 0xff;
              fg = p;
              i += 1;
            }
            i += 1;
          }
        }
      } else if (p == 48) {
        if (i + 1 < parCount) {
          // bg color 256
          if (pars[i + 1] == 2) {
            // Well this is a problem, if there are 3 arguments, expect R/G/B, if there are
            // more than 3, skip the first that would be the colorspace
            if (i + 5 < parCount) {
              i += 1;
            }
            if (i + 4 < parCount) {
              bg = _terminal.matchColor(
                  pars[i + 2] & 0xff, pars[i + 3] & 0xff, pars[i + 4] & 0xff);
              if (bg == -1) bg = 0x1ff;
            }
            // Given the historical disagreement that was caused by an ambiguous spec,
            // we eat all the remaining parameters.
            i = parCount;
          } else if (pars[i + 1] == 5) {
            if (i + 2 < parCount) {
              p = pars[i + 2] & 0xff;
              bg = p;
              i += 1;
            }
            i += 1;
          }
        }
      } else if (p == 100) {
        // reset fg/bg
        fg = (def >> 9) & 0x1ff;
        bg = def & 0x1ff;
      } else {
        _terminal.error("Unknown SGR attribute: %d.", [p]);
      }
    }
    _terminal.curAttr = (flags << 18) | (fg << 9) | bg;
  }

  void _resetMode(List<int> pars, String collect) {
    if (pars.length == 0) return;

    if (pars.length > 1) {
      for (var i = 0; i < pars.length; i++) _terminal.csiDECRESET(pars[i], "");

      return;
    }
    _terminal.csiDECRESET(pars[0], collect);
  }

  void _setMode(List<int> pars, String collect) {
    if (pars.length == 0) return;

    if (pars.length > 1) {
      for (var i = 0; i < pars.length; i++) _terminal.csiDECSET(pars[i], "");

      return;
    }
    _terminal.csiDECSET(pars[0], collect);
  }

  //
  // CSI Ps g  Tab Clear (TBC).
  //     Ps = 0  -> Clear Current Column (default).
  //     Ps = 3  -> Clear All.
  // Potentially:
  //   Ps = 2  -> Clear Stops on Line.
  //   http://vt100.net/annarbor/aaa-ug/section6.html
  //
  void _tabClear(List<int> pars) {
    var p = pars.length == 0 ? 0 : pars[0];
    var buffer = _terminal.buffer;
    if (p == 0)
      buffer.clearStop(buffer.x);
    else if (p == 3) buffer.clearTabStops();
  }

  //
  // CSI Ps ; Ps f
  //   Horizontal and Vertical Position [row;column] (default =
  //   [1,1]) (HVP).
  //
  void _hVPosition(List<int> pars) {
    int p = 1;
    int q = 1;
    if (pars.length > 0) {
      p = max(pars[0], 1);
      if (pars.length > 1) q = max(pars[1], 1);
    }
    var buffer = _terminal.buffer;
    buffer.y = p - 1;
    if (buffer.y >= _terminal.rows) buffer.y = _terminal.rows - 1;

    buffer.x = q - 1;
    if (buffer.x >= _terminal.cols) buffer.x = _terminal.cols - 1;
  }

  //
  // CSI Pm e  Vertical Position Relative (VPR)
  //   [rows] (default = [row+1,column])
  // reuse CSI Ps B ?
  //
  void _vPositionRelative(List<int> pars) {
    var p = max(pars.length == 0 ? 1 : pars[0], 1);
    var buffer = _terminal.buffer;

    var newY = buffer.y + p;

    if (newY >= _terminal.rows) {
      buffer.y = _terminal.rows - 1;
    } else
      buffer.y = newY;

    // If the end of the line is hit, prevent this action from wrapping around to the next line.
    if (buffer.x >= _terminal.cols) buffer.x--;
  }

  //
  // CSI Pm d  Vertical Position Absolute (VPA)
  //   [row] (default = [1,column])
  //
  void _linePosAbsolute(List<int> pars) {
    var p = max(pars.length == 0 ? 1 : pars[0], 1);
    var buffer = _terminal.buffer;

    if (p - 1 >= _terminal.rows)
      buffer.y = _terminal.rows - 1;
    else
      buffer.y = p - 1;
  }

  //
  // CSI Ps b  Repeat the preceding graphic character Ps times (REP).
  //
  void _repeatPrecedingCharacter(List<int> pars) {
    var p = max(pars.length == 0 ? 1 : pars[0], 1);

    var buffer = _terminal.buffer;
    var line = buffer.lines[buffer.yBase + buffer.y];
    CharData cd = buffer.x - 1 < 0
        ? new CharData(CharData.DefaultAttr)
        : line![buffer.x - 1];
    line!.replaceCells(buffer.x, buffer.x + p, cd);
    // FIXME: no UpdateRange here?
  }

  //
  //CSI Pm a  Character Position Relative
  //  [columns] (default = [row,col+1]) (HPR)
  //reuse CSI Ps C ?
  //
  void _hPositionRelative(List<int> pars) {
    var p = max(pars.length == 0 ? 1 : pars[0], 1);
    var buffer = _terminal.buffer;

    buffer.x += p;
    if (buffer.x >= _terminal.cols) buffer.x = _terminal.cols - 1;
  }

  //
  // CSI Pm `  Character Position Absolute
  //   [column] (default = [row,1]) (HPA).
  //
  void _charPosAbsolute(List<int> pars) {
    var p = max(pars.length == 0 ? 1 : pars[0], 1);
    var buffer = _terminal.buffer;

    buffer.x = p - 1;
    if (buffer.x >= _terminal.cols) buffer.x = _terminal.cols - 1;
  }

  //
  // CSI Ps X
  // Erase Ps Character(s) (default = 1) (ECH).
  //
  void _eraseChars(List<int> pars) {
    var p = max(pars.length == 0 ? 1 : pars[0], 1);

    var buffer = _terminal.buffer;
    buffer.lines[buffer.y + buffer.yBase]!.replaceCells(
        buffer.x, buffer.x + p, new CharData(_terminal.eraseAttr()));
  }

  //
  // CSI Ps T  Scroll down Ps lines (default = 1) (SD).
  //
  void _scrollDown(List<int> pars) {
    var p = max(pars.length == 0 ? 1 : pars[0], 1);
    var buffer = _terminal.buffer;

    while (p-- != 0) {
      buffer.lines.splice(buffer.yBase + buffer.scrollBottom, 1, []);
      buffer.lines.splice(buffer.yBase + buffer.scrollBottom, 0,
          [buffer.getBlankLine(CharData.DefaultAttr)]);
    }
    // this.maxRange();
    _terminal.updateRange(buffer.scrollTop);
    _terminal.updateRange(buffer.scrollBottom);
  }

  //
  // CSI Ps S  Scroll up Ps lines (default = 1) (SU).
  //
  void _scrollUp(List<int> pars) {
    var p = max(pars.length == 0 ? 1 : pars[0], 1);
    var buffer = _terminal.buffer;

    while (p-- != 0) {
      buffer.lines.splice(buffer.yBase + buffer.scrollTop, 1, []);
      buffer.lines.splice(buffer.yBase + buffer.scrollBottom, 0,
          [buffer.getBlankLine(CharData.DefaultAttr)]);
    }
    // this.maxRange();
    _terminal.updateRange(buffer.scrollTop);
    _terminal.updateRange(buffer.scrollBottom);
  }

  //
  // CSI Ps K  Erase in Line (EL).
  //     Ps = 0  -> Erase to Right (default).
  //     Ps = 1  -> Erase to Left.
  //     Ps = 2  -> Erase All.
  // CSI ? Ps K
  //   Erase in Line (DECSEL).
  //     Ps = 0  -> Selective Erase to Right (default).
  //     Ps = 1  -> Selective Erase to Left.
  //     Ps = 2  -> Selective Erase All.
  //
  void _eraseInLine(List<int> pars) {
    var p = pars.length == 0 ? 0 : pars[0];
    var buffer = _terminal.buffer;
    switch (p) {
      case 0:
        _eraseInBufferLine(buffer.y, buffer.x, _terminal.cols);
        break;
      case 1:
        _eraseInBufferLine(buffer.y, 0, buffer.x + 1);
        break;
      case 2:
        _eraseInBufferLine(buffer.y, 0, _terminal.cols);
        break;
    }
    _terminal.updateRange(buffer.y);
  }

  //
  // CSI Ps J  Erase in Display (ED).
  //     Ps = 0  -> Erase Below (default).
  //     Ps = 1  -> Erase Above.
  //     Ps = 2  -> Erase All.
  //     Ps = 3  -> Erase Saved Lines (xterm).
  // CSI ? Ps J
  //   Erase in Display (DECSED).
  //     Ps = 0  -> Selective Erase Below (default).
  //     Ps = 1  -> Selective Erase Above.
  //     Ps = 2  -> Selective Erase All.
  //
  void _eraseInDisplay(List<int> pars) {
    var p = pars.length == 0 ? 0 : pars[0];
    var buffer = _terminal.buffer;
    int j;
    switch (p) {
      case 0:
        j = buffer.y;
        _terminal.updateRange(j);
        _eraseInBufferLine(j++, buffer.x, _terminal.cols, buffer.x == 0);
        for (; j < _terminal.rows; j++) {
          _resetBufferLine(j);
        }
        _terminal.updateRange(j - 1);
        break;
      case 1:
        j = buffer.y;
        _terminal.updateRange(j);
        // Deleted front part of line and everything before. This line will no longer be wrapped.
        _eraseInBufferLine(j, 0, buffer.x + 1, true);
        if (buffer.x + 1 >= _terminal.cols) {
          // Deleted entire previous line. This next line can no longer be wrapped.
          buffer.lines[j + 1]!.isWrapped = false;
        }
        while (j-- != 0) {
          _resetBufferLine(j);
        }
        _terminal.updateRange(0);
        break;
      case 2:
        j = _terminal.rows;
        _terminal.updateRange(j - 1);
        while (j-- != 0) {
          _resetBufferLine(j);
        }
        _terminal.updateRange(0);
        break;
      case 3:
        // Clear scrollback (everything not in viewport)
        var scrollBackSize = buffer.lines.length - _terminal.rows;
        if (scrollBackSize > 0) {
          buffer.lines.trimStart(scrollBackSize);
          buffer.yBase = max(buffer.yBase - scrollBackSize, 0);
          buffer.yDisp = max(buffer.yDisp - scrollBackSize, 0);
        }
        break;
    }
  }

  //
  // CSI Ps I
  //   Cursor Forward Tabulation Ps tab stops (default = 1) (CHT).
  //
  void _cursorForwardTab(List<int> pars) {
    int param = max(pars.length > 0 ? pars[0] : 1, 1);
    var buffer = _terminal.buffer;
    while (param-- != 0) buffer.x = buffer.nextTabStop();
  }

  //
  // CSI Ps F
  // Cursor Preceding Line Ps Times (default = 1) (CNL).
  // reuse CSI Ps A ?
  //
  void _cursorPrecedingLine(List<int> pars) {
    int param = max(pars.length > 0 ? pars[0] : 1, 1);
    var buffer = _terminal.buffer;

    buffer.y -= param;
    var newY = buffer.y - param;
    if (newY < 0)
      buffer.y = 0;
    else
      buffer.y = newY;
    buffer.x = 0;
  }

  //
  // CSI Ps E
  // Cursor Next Line Ps Times (default = 1) (CNL).
  // same as CSI Ps B?
  //
  void _cursorNextLine(List<int> pars) {
    int param = max(pars.length > 0 ? pars[0] : 1, 1);
    var buffer = _terminal.buffer;

    var newY = buffer.y + param;

    if (newY >= _terminal.rows)
      buffer.y = _terminal.rows - 1;
    else
      buffer.y = newY;

    buffer.x = 0;
  }

  //
  // CSI Ps @
  // Insert Ps (Blank) Character(s) (default = 1) (ICH).
  //
  void _insertChars(List<int> pars) {
    _terminal.restrictCursor();
    var buffer = _terminal.buffer;
    var cd = CharData(_terminal.eraseAttr());

    buffer.lines[buffer.y + buffer.yBase]!.insertCells(
        buffer.x,
        pars.length > 0 ? max(pars[0], 1) : 1,
        _terminal.marginMode ? buffer.marginRight : buffer.cols - 1,
        cd);

    _terminal.updateRange(buffer.y);
  }

  void _printStateReset() {
    _readingBuffer.reset();
  }

  void _print(Uint8List data, int start, int end) {
    _readingBuffer.prepare(data, start, end - start);

    var buffer = _terminal.buffer;
    var charset = _terminal.charset;
    var screenReaderMode = _terminal.options.screenReaderMode;
    var cols = _terminal.cols;
    var wrapAroundMode = _terminal.wraparound;
    var insertMode = _terminal.insertMode;
    var curAttr = _terminal.curAttr;
    var bufferRow = buffer.lines[buffer.y + buffer.yBase];

    _terminal.updateRange(buffer.y);

    while (_readingBuffer.hasNext) {
      String code;
      int bufferValue = _readingBuffer.getNext();
      var n = RuneUtils.expectedSizeFromFirstByte(bufferValue);
      if (n == -1) {
        // Invalid UTF-8 sequence, client sent us some junk, happens if we run with the wrong locale set
        // for example if LANG=en
        code = String.fromCharCode(bufferValue);
      } else if (n == 1) {
        code = String.fromCharCode(bufferValue);
      } else {
        if (_readingBuffer.bytesLeft >= (n - 1)) {
          var x = Uint8List(n);
          x[0] = bufferValue;
          for (int j = 1; j < n; j++) {
            x[j] = _readingBuffer.getNext();
          }

          code = _utf8Decoder.convert(x.toList(growable: false));
        } else {
          _readingBuffer.putback(bufferValue);
          return;
        }
      }

      // MIGUEL-TODO: I suspect this needs to be a stirng in C# to cope with Grapheme clusters
      var ch = code;

      // calculate print space
      // expensive call, therefore we save width in line buffer

      // TODO: This is wrong, we only have one byte at this point, we do not have a full rune.
      // The correct fix includes the upper parser tracking the "pending" data across invocations
      // until a valid UTF-8 string comes in, and *then* we can call this method
      // var chWidth = Rune.ColumnWidth ((Rune)code);

      // 1 until we get a fixed NStack
      var chWidth = 1;

      // get charset replacement character
      // charset are only defined for ASCII, therefore we only
      // search for an replacement char if code < 127
      if (code.runes.first < 127 && charset != null) {
        // MIGUEL-FIXME - this is broken for dutch charset that returns two letters "ij", need to figure out what to do
        final str = charset[code];
        if (str != null) {
          ch = str[0];
          code = ch;
        }
      }
      if (screenReaderMode) _terminal.emitChar(ch.runes.first);

      // insert combining char at last cursor position
      // FIXME: needs handling after cursor jumps
      // buffer.x should never be 0 for a combining char
      // since they always follow a cell consuming char
      // therefore we can test for buffer.x to avoid overflow left
      if (chWidth == 0 && buffer.x > 0) {
        // MIGUEL TODO: in the original code the getter might return a null value
        // does this mean that JS returns null for out of bounsd?
        if (buffer.x >= 1 && buffer.x < bufferRow!.length) {
          var chMinusOne = bufferRow[buffer.x - 1];
          if (chMinusOne.width == 0) {
            // found empty cell after fullwidth, need to go 2 cells back
            // it is save to step 2 cells back here
            // since an empty cell is only set by fullwidth chars
            if (buffer.x >= 2) {
              var chMinusTwo = bufferRow[buffer.x - 2];

              chMinusTwo.code += ch.runes.first;
              chMinusTwo.rune = code;
              bufferRow[buffer.x - 2] =
                  chMinusTwo; // must be set explicitly now
            }
          } else {
            chMinusOne.code += ch.runes.first;
            chMinusOne.rune = code;
            bufferRow[buffer.x - 1] = chMinusOne; // must be set explicitly now
          }
        }
        continue;
      }

      // goto next line if ch would overflow
      // TODO: needs a global min _terminal width of 2
      // FIXME: additionally ensure chWidth fits into a line
      //   -->  maybe forbid cols<xy at higher level as it would
      //        introduce a bad runtime penalty here
      var right = _terminal.marginMode ? buffer.marginRight : cols - 1;
      if (buffer.x + chWidth - 1 > right) {
        // autowrap - DECAWM
        // automatically wraps to the beginning of the next line
        if (wrapAroundMode) {
          buffer.x = _terminal.marginMode ? buffer.marginLeft : 0;

          if (buffer.y >= buffer.scrollBottom) {
            _terminal.scroll(true);
          } else {
            // The line already exists (eg. the initial viewport), mark it as a
            // wrapped line
            buffer.lines[++buffer.y]!.isWrapped = true;
          }

          // row changed, get it again
          bufferRow = buffer.lines[buffer.y + buffer.yBase];
        } else {
          if (chWidth == 2) {
            // FIXME: check for xterm behavior
            // What to do here? We got a wide char that does not fit into last cell
            continue;
          }

          buffer.x = right;
        }
      }

      var empty = CharData.nul;
      empty.attribute = curAttr;
      // insert mode: move characters to right
      if (insertMode) {
        // right shift cells according to the width
        bufferRow!.insertCells(buffer.x, chWidth,
            _terminal.marginMode ? buffer.marginRight : cols - 1, empty);
        // test last cell - since the last cell has only room for
        // a halfwidth char any fullwidth shifted there is lost
        // and will be set to eraseChar
        var lastCell = bufferRow[cols - 1];
        if (lastCell.width == 2) bufferRow[cols - 1] = empty;
      }

      // write current char to buffer and advance cursor
      var charData =
          CharData(curAttr, rune: code, width: chWidth, code: ch.runes.first);
      bufferRow![buffer.x++] = charData;

      // fullwidth char - also set next cell to placeholder stub and advance cursor
      // for graphemes bigger than fullwidth we can simply loop to zero
      // we already made sure above, that buffer.x + chWidth will not overflow right
      if (chWidth > 0) {
        while (--chWidth != 0) {
          bufferRow[buffer.x++] = empty;
        }
      }
    }
    _terminal.updateRange(buffer.y);
    _readingBuffer.done();
  }
}
