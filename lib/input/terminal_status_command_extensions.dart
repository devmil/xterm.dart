import 'dart:math';

import 'package:xterm/terminal/terminal.dart';

extension TerminalStatusCommandExtensions on Terminal {
  // CSI Ps c  Send Device Attributes (Primary DA).
  //     Ps = 0  or omitted -> request attributes from terminal.  The
  //     response depends on the decTerminalID resource setting.
  //     -> CSI ? 1 ; 2 c  (``VT100 with Advanced Video Option'')
  //     -> CSI ? 1 ; 0 c  (``VT101 with No Options'')
  //     -> CSI ? 6 c  (``VT102'')
  //     -> CSI ? 6 0 ; 1 ; 2 ; 6 ; 8 ; 9 ; 1 5 ; c  (``VT220'')
  //   The VT100-style response parameters do not mean anything by
  //   themselves.  VT220 parameters do, telling the host what fea-
  //   tures the terminal supports:
  //     Ps = 1  -> 132-columns.
  //     Ps = 2  -> Printer.
  //     Ps = 6  -> Selective erase.
  //     Ps = 8  -> User-defined keys.
  //     Ps = 9  -> National replacement character sets.
  //     Ps = 1 5  -> Technical characters.
  //     Ps = 2 2  -> ANSI color, e.g., VT525.
  //     Ps = 2 9  -> ANSI text locator (i.e., DEC Locator mode).
  // CSI > Ps c
  //   Send Device Attributes (Secondary DA).
  //     Ps = 0  or omitted -> request the terminal's identification
  //     code.  The response depends on the decTerminalID resource set-
  //     ting.  It should apply only to VT220 and up, but xterm extends
  //     this to VT100.
  //     -> CSI  > Pp ; Pv ; Pc c
  //   where Pp denotes the terminal type
  //     Pp = 0  -> ``VT100''.
  //     Pp = 1  -> ``VT220''.
  //   and Pv is the firmware version (for xterm, this was originally
  //   the XFree86 patch number, starting with 95).  In a DEC termi-
  //   nal, Pc indicates the ROM cartridge registration number and is
  //   always zero.
  // More information:
  //   xterm/charproc.c - line 2012, for more information.
  //   vim responds with ^[[?0c or ^[[?1c after the terminal's response (?)
  //
  csiDA1(List<int> pars, String collect) {
    if (pars.length > 0 && pars[0] > 0) return;

    if (collect == ">" || collect == ">0") {
      // DA2 Secondary Device Attributes
      if (pars.length == 0 || pars[0] == 0) {
        var vt510 = 61; // we identified as a vt510
        var kbd = 1; // PC-style keyboard
        sendResponse("${controlCodes.csi}>${vt510};20;${kbd}c");
        return;
      }

      return;
    }

    var name = options.termName;
    if (collect == "") {
      if (name.startsWith("xterm") ||
          name.startsWith("rxvt-unicode") ||
          name.startsWith("screen")) {
        sendResponse("${controlCodes.csi}?1;2c");
      } else if (name.startsWith("linux")) {
        sendResponse("${controlCodes.csi}?6c");
      }
    } else if (collect == ">") {
      // xterm and urxvt
      // seem to spit this
      // out around ~370 times (?).
      if (name.startsWith("xterm")) {
        sendResponse("\x1b[>0;276;0c");
      } else if (name.startsWith("rxvt-unicode")) {
        sendResponse("\x1b[>85;95;0c");
      } else if (name.startsWith("linux")) {
        // not supported by linux console.
        // linux console echoes parameters.
        sendResponse("" + pars[0].toString() + 'c');
      } else if (name.startsWith("screen")) {
        sendResponse("\x1b[>83;40003;0c");
      }
    }
  }

  /// <summary>
  /// CSI Ps n  Device Status Report (DSR).
  ///     Ps = 5  -> Status Report.  Result (``OK'') is
  ///   CSI 0 n
  ///     Ps = 6  -> Report Cursor Position (CPR) [row;column].
  ///   Result is
  ///   CSI r ; c R
  /// CSI ? Ps n
  ///   Device Status Report (DSR, DEC-specific).
  ///     Ps = 6  -> Report Cursor Position (CPR) [row;column] as CSI
  ///     ? r ; c R (assumes page is zero).
  ///     Ps = 1 5  -> Report Printer status as CSI ? 1 0  n  (ready).
  ///     or CSI ? 1 1  n  (not ready).
  ///     Ps = 2 5  -> Report UDK status as CSI ? 2 0  n  (unlocked)
  ///     or CSI ? 2 1  n  (locked).
  ///     Ps = 2 6  -> Report Keyboard status as
  ///   CSI ? 2 7  ;  1  ;  0  ;  0  n  (North American).
  ///   The last two parameters apply to VT400 & up, and denote key-
  ///   board ready and LK01 respectively.
  ///     Ps = 5 3  -> Report Locator status as
  ///   CSI ? 5 3  n  Locator available, if compiled-in, or
  ///   CSI ? 5 0  n  No Locator, if not.
  /// </summary>
  csiDSR(List<int> pars, String collect) {
    if (collect == "") {
      switch (pars[0]) {
        case 5:
          // status report
          sendResponse("\x1b[0n");
          break;
        case 6:
          // cursor position
          var y = max(1, buffer.y + 1 - (originMode ? buffer.scrollTop : 0));
          // Need the max, because the cursor could be before the leftMargin
          var x = max(1, buffer.x + 1 - (originMode ? buffer.marginLeft : 0));
          sendResponse("\x1b[${y};${x}R");
          break;
      }
    } else if (collect == "?") {
      // modern xterm doesnt seem to
      // respond to any of these except ?6, 6, and 5
      switch (pars[0]) {
        case 6:
          // cursor position
          var y = buffer.y + 1 - (originMode ? buffer.scrollTop : 0);
          // Need the max, because the cursor could be before the leftMargin
          var x =
              max(1, buffer.x + 1 - (isUsingMargins() ? buffer.marginLeft : 0));
          sendResponse("\x1b[?${y};${x};1R");
          break;
        case 15:
          // Request printer status report, we respond "We are ready"
          sendResponse("${controlCodes.csi}?10n");
          break;
        case 25:
          // We respond "User defined keys are locked"
          sendResponse("${controlCodes.csi}?21n");
          break;
        case 26:
          // Requests keyboard type
          // We respond "American keyboard", TODO: worth plugging something else?  Mac perhaps?
          sendResponse("${controlCodes.csi}?27;1;0;0n");
          break;
        case 53:
          // no dec locator/mouse
          // this.handler(C0.ESC + '[?50n');
          break;
        case 55:
          // Request locator status
          sendResponse("${controlCodes.csi}?53n");
          break;
        case 56:
          // What kind of locator we have, we reply mouse, but perhaps on iOS we should respond something else
          sendResponse("${controlCodes.csi}?57;1n");
          break;
        case 62:
          // Macro space report
          sendResponse("${controlCodes.csi}0*{'{'}");
          break;
        case 63:
          // Requests checksum of macros, we return 0
          var id = pars.length > 1 ? pars[1] : 0;
          sendResponse("${controlCodes.dcs}${id}!~0000${controlCodes.st}");
          break;
        case 75:
          // Data integrity report, no issues:
          sendResponse("${controlCodes.csi}?70n");
          break;
        case 85:
          // Multiple session status, we reply single session
          sendResponse("${controlCodes.csi}?83n");
          break;
      }
    }
  }
}
