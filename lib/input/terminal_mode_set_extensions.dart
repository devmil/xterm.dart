import 'package:xterm/buffer/char_data.dart';
import 'package:xterm/terminal/char_sets.dart';
import 'package:xterm/terminal/terminal.dart';

import 'mouse_mode.dart';
import 'mouse_protocol_encoding.dart';

extension TerminalModeSetExtensions on Terminal {
  /// <summary>
  /// Sets the mode from csi DECSTR
  /// </summary>
  // CSI Pm h  Set Mode (SM).
  //     Ps = 2  -> Keyboard Action Mode (AM).
  //     Ps = 4  -> Insert Mode (IRM).
  //     Ps = 1 2  -> Send/receive (SRM).
  //     Ps = 2 0  -> Automatic Newline (LNM).
  // CSI ? Pm h
  //   DEC Private Mode Set (DECSET).
  //     Ps = 1  -> Application Cursor Keys (DECCKM).
  //     Ps = 2  -> Designate USASCII for character sets G0-G3
  //     (DECANM), and set VT100 mode.
  //     Ps = 3  -> 132 Column Mode (DECCOLM).
  //     Ps = 4  -> Smooth (Slow) Scroll (DECSCLM).
  //     Ps = 5  -> Reverse Video (DECSCNM).
  //     Ps = 6  -> Origin Mode (DECOM).
  //     Ps = 7  -> Wraparound Mode (DECAWM).
  //     Ps = 8  -> Auto-repeat Keys (DECARM).
  //     Ps = 9  -> Send Mouse X & Y on button press.  See the sec-
  //     tion Mouse Tracking.
  //     Ps = 1 0  -> Show toolbar (rxvt).
  //     Ps = 1 2  -> Start Blinking Cursor (att610).
  //     Ps = 1 8  -> Print form feed (DECPFF).
  //     Ps = 1 9  -> Set print extent to full screen (DECPEX).
  //     Ps = 2 5  -> Show Cursor (DECTCEM).
  //     Ps = 3 0  -> Show scrollbar (rxvt).
  //     Ps = 3 5  -> Enable font-shifting functions (rxvt).
  //     Ps = 3 8  -> Enter Tektronix Mode (DECTEK).
  //     Ps = 4 0  -> Allow 80 -> 132 Mode.
  //     Ps = 4 1  -> more(1) fix (see curses resource).
  //     Ps = 4 2  -> Enable Nation Replacement Character sets (DECN-
  //     RCM).
  //     Ps = 4 4  -> Turn On Margin Bell.
  //     Ps = 4 5  -> Reverse-wraparound Mode.
  //     Ps = 4 6  -> Start Logging.  This is normally disabled by a
  //     compile-time option.
  //     Ps = 4 7  -> Use Alternate Screen Buffer.  (This may be dis-
  //     abled by the titeInhibit resource).
  //     Ps = 6 6  -> Application keypad (DECNKM).
  //     Ps = 6 7  -> Backarrow key sends backspace (DECBKM).
  //     Ps = 1 0 0 0  -> Send Mouse X & Y on button press and
  //     release.  See the section Mouse Tracking.
  //     Ps = 1 0 0 1  -> Use Hilite Mouse Tracking.
  //     Ps = 1 0 0 2  -> Use Cell Motion Mouse Tracking.
  //     Ps = 1 0 0 3  -> Use All Motion Mouse Tracking.
  //     Ps = 1 0 0 4  -> Send FocusIn/FocusOut events.
  //     Ps = 1 0 0 5  -> Enable Extended Mouse Mode.
  //     Ps = 1 0 1 0  -> Scroll to bottom on tty output (rxvt).
  //     Ps = 1 0 1 1  -> Scroll to bottom on key press (rxvt).
  //     Ps = 1 0 3 4  -> Interpret "meta" key, sets eighth bit.
  //     (enables the eightBitInput resource).
  //     Ps = 1 0 3 5  -> Enable special modifiers for Alt and Num-
  //     Lock keys.  (This enables the numLock resource).
  //     Ps = 1 0 3 6  -> Send ESC   when Meta modifies a key.  (This
  //     enables the metaSendsEscape resource).
  //     Ps = 1 0 3 7  -> Send DEL from the editing-keypad Delete
  //     key.
  //     Ps = 1 0 3 9  -> Send ESC  when Alt modifies a key.  (This
  //     enables the altSendsEscape resource).
  //     Ps = 1 0 4 0  -> Keep selection even if not highlighted.
  //     (This enables the keepSelection resource).
  //     Ps = 1 0 4 1  -> Use the CLIPBOARD selection.  (This enables
  //     the selectToClipboard resource).
  //     Ps = 1 0 4 2  -> Enable Urgency window manager hint when
  //     Control-G is received.  (This enables the bellIsUrgent
  //     resource).
  //     Ps = 1 0 4 3  -> Enable raising of the window when Control-G
  //     is received.  (enables the popOnBell resource).
  //     Ps = 1 0 4 7  -> Use Alternate Screen Buffer.  (This may be
  //     disabled by the titeInhibit resource).
  //     Ps = 1 0 4 8  -> Save cursor as in DECSC.  (This may be dis-
  //     abled by the titeInhibit resource).
  //     Ps = 1 0 4 9  -> Save cursor as in DECSC and use Alternate
  //     Screen Buffer, clearing it first.  (This may be disabled by
  //     the titeInhibit resource).  This combines the effects of the 1
  //     0 4 7  and 1 0 4 8  modes.  Use this with terminfo-based
  //     applications rather than the 4 7  mode.
  //     Ps = 1 0 5 0  -> Set terminfo/termcap function-key mode.
  //     Ps = 1 0 5 1  -> Set Sun function-key mode.
  //     Ps = 1 0 5 2  -> Set HP function-key mode.
  //     Ps = 1 0 5 3  -> Set SCO function-key mode.
  //     Ps = 1 0 6 0  -> Set legacy keyboard emulation (X11R6).
  //     Ps = 1 0 6 1  -> Set VT220 keyboard emulation.
  //     Ps = 2 0 0 4  -> Set bracketed paste mode.
  // Modes:
  //   http: *vt100.net/docs/vt220-rm/chapter4.html
  csiDECSET(int par, String collect) {
    if (collect == "") {
      switch (par) {
        case 4:
          //Console.WriteLine ("This needs to handle the replace mode as well");
          // https://vt100.net/docs/vt510-rm/IRM.html
          this.insertMode = true;
          break;
        case 20:
          this.lineFeedMode = false;
          break;
      }
    } else if (collect == "?") {
      switch (par) {
        case 1:
          this.applicationCursor = true;
          break;
        case 2:
          this.setgCharset(0, CharSets.Default);
          this.setgCharset(1, CharSets.Default);
          this.setgCharset(2, CharSets.Default);
          this.setgCharset(3, CharSets.Default);
          // set VT100 mode here
          break;
        case 3: // 132 col mode
          if (this.allow80To132) {
            this.resize(132, this.rows);
            this.reset();
            this.delegate.sizeChanged(this);
            this.notifyListeners();
          }
          break;
        case 5:
          // Inverted colors
          this.curAttr = CharData.InvertedAttr;
          break;
        case 6:
          this.originMode = true;
          break;
        case 7:
          this.wraparound = true;
          break;
        case 9: // X10 Mouse
          // no release, no motion, no wheel, no modifiers.
          this.mouseMode = MouseMode.X10;
          break;
        case 12:
          // this.cursorBlink = true;
          break;
        case 40:
          this.allow80To132 = true;
          break;
        case 45:
          // Xterm Reverse Wrap-around
          // reverse wraparound can only be enabled if Auto-wrap is enabled (DECAWM)
          if (this.wraparound) {
            this.reverseWraparound = true;
          }
          break;
        case 66:
          this.log("Serial port requested application keypad.");
          this.applicationKeypad = true;
          this.syncScrollArea();
          break;
        case 69:
          // Enable left and right margin mode (DECLRMM),
          this.marginMode = true;
          break;
        case 1000: // vt200 mouse
          // no motion.
          // no modifiers, except control on the wheel.
          this.mouseMode = MouseMode.VT200;
          break;
        case 1002:
          // SET_BTN_EVENT_MOUSE
          this.mouseMode = MouseMode.ButtonEventTracking;
          break;
        case 1003:
          // SET_ANY_EVENT_MOUSE
          this.mouseMode = MouseMode.AnyEvent;
          break;
        case 1004: // send focusin/focusout events
          // focusin: ^[[I
          // focusout: ^[[O
          this.sendFocus = true;
          break;
        case 1005: // utf8 ext mode mouse
          // for wide terminals
          // simply encodes large values as utf8 characters
          this.mouseProtocol = MouseProtocolEncoding.UTF8;
          break;
        case 1006: // sgr ext mode mouse
          this.mouseProtocol = MouseProtocolEncoding.SGR;
          // for wide terminals
          // does not add 32 to fields
          // press: ^[[<b;x;yM
          // release: ^[[<b;x;ym
          break;
        case 1015: // urxvt ext mode mouse
          this.mouseProtocol = MouseProtocolEncoding.URXVT;
          // for wide terminals
          // numbers for fields
          // press: ^[[b;x;yM
          // motion: ^[[b;x;yT
          break;
        case 25: // show cursor
          this.cursorHidden = false;
          break;
        case 1048: // alt screen cursor

          this.saveCursor();
          break;
        case 1049: // alt screen buffer cursor
          this.saveCursor();
          this.buffers.activateAltBuffer(this.eraseAttr());
          this.refresh(0, this.rows - 1);
          this.syncScrollArea();
          this.showCursor();
          break;
        case 47: // alt screen buffer
        case 1047: // alt screen buffer
          this.buffers.activateAltBuffer(this.eraseAttr());
          this.refresh(0, this.rows - 1);
          this.syncScrollArea();
          this.showCursor();
          break;
        case 2004: // bracketed paste mode (https://cirw.in/blog/bracketed-paste)
          this.bracketedPasteMode = true;
          break;
      }
    }
  }

  //CSI Pm l  Reset Mode (RM).
  //    Ps = 2  -> Keyboard Action Mode (AM).
  //    Ps = 4  -> Replace Mode (IRM).
  //    Ps = 1 2  -> Send/receive (SRM).
  //    Ps = 2 0  -> Normal Linefeed (LNM).
  //CSI ? Pm l
  //  DEC Private Mode Reset (DECRST).
  //    Ps = 1  -> Normal Cursor Keys (DECCKM).
  //    Ps = 2  -> Designate VT52 mode (DECANM).
  //    Ps = 3  -> 80 Column Mode (DECCOLM).
  //    Ps = 4  -> Jump (Fast) Scroll (DECSCLM).
  //    Ps = 5  -> Normal Video (DECSCNM).
  //    Ps = 6  -> Normal Cursor Mode (DECOM).
  //    Ps = 7  -> No Wraparound Mode (DECAWM).
  //    Ps = 8  -> No Auto-repeat Keys (DECARM).
  //    Ps = 9  -> Don't send Mouse X & Y on button press.
  //    Ps = 1 0  -> Hide toolbar (rxvt).
  //    Ps = 1 2  -> Stop Blinking Cursor (att610).
  //    Ps = 1 8  -> Don't print form feed (DECPFF).
  //    Ps = 1 9  -> Limit print to scrolling region (DECPEX).
  //    Ps = 2 5  -> Hide Cursor (DECTCEM).
  //    Ps = 3 0  -> Don't show scrollbar (rxvt).
  //    Ps = 3 5  -> Disable font-shifting functions (rxvt).
  //    Ps = 4 0  -> Disallow 80 -> 132 Mode.
  //    Ps = 4 1  -> No more(1) fix (see curses resource).
  //    Ps = 4 2  -> Disable Nation Replacement Character sets (DEC-
  //    NRCM).
  //    Ps = 4 4  -> Turn Off Margin Bell.
  //    Ps = 4 5  -> No Reverse-wraparound Mode.
  //    Ps = 4 6  -> Stop Logging.  (This is normally disabled by a
  //    compile-time option).
  //    Ps = 4 7  -> Use Normal Screen Buffer.
  //    Ps = 6 6  -> Numeric keypad (DECNKM).
  //    Ps = 6 7  -> Backarrow key sends delete (DECBKM).
  //    Ps = 1 0 0 0  -> Don't send Mouse X & Y on button press and
  //    release.  See the section Mouse Tracking.
  //    Ps = 1 0 0 1  -> Don't use Hilite Mouse Tracking.
  //    Ps = 1 0 0 2  -> Don't use Cell Motion Mouse Tracking.
  //    Ps = 1 0 0 3  -> Don't use All Motion Mouse Tracking.
  //    Ps = 1 0 0 4  -> Don't send FocusIn/FocusOut events.
  //    Ps = 1 0 0 5  -> Disable Extended Mouse Mode.
  //    Ps = 1 0 1 0  -> Don't scroll to bottom on tty output
  //    (rxvt).
  //    Ps = 1 0 1 1  -> Don't scroll to bottom on key press (rxvt).
  //    Ps = 1 0 3 4  -> Don't interpret "meta" key.  (This disables
  //    the eightBitInput resource).
  //    Ps = 1 0 3 5  -> Disable special modifiers for Alt and Num-
  //    Lock keys.  (This disables the numLock resource).
  //    Ps = 1 0 3 6  -> Don't send ESC  when Meta modifies a key.
  //    (This disables the metaSendsEscape resource).
  //    Ps = 1 0 3 7  -> Send VT220 Remove from the editing-keypad
  //    Delete key.
  //    Ps = 1 0 3 9  -> Don't send ESC  when Alt modifies a key.
  //    (This disables the altSendsEscape resource).
  //    Ps = 1 0 4 0  -> Do not keep selection when not highlighted.
  //    (This disables the keepSelection resource).
  //    Ps = 1 0 4 1  -> Use the PRIMARY selection.  (This disables
  //    the selectToClipboard resource).
  //    Ps = 1 0 4 2  -> Disable Urgency window manager hint when
  //    Control-G is received.  (This disables the bellIsUrgent
  //    resource).
  //    Ps = 1 0 4 3  -> Disable raising of the window when Control-
  //    G is received.  (This disables the popOnBell resource).
  //    Ps = 1 0 4 7  -> Use Normal Screen Buffer, clearing screen
  //    first if in the Alternate Screen.  (This may be disabled by
  //    the titeInhibit resource).
  //    Ps = 1 0 4 8  -> Restore cursor as in DECRC.  (This may be
  //    disabled by the titeInhibit resource).
  //    Ps = 1 0 4 9  -> Use Normal Screen Buffer and restore cursor
  //    as in DECRC.  (This may be disabled by the titeInhibit
  //    resource).  This combines the effects of the 1 0 4 7  and 1 0
  //    4 8  modes.  Use this with terminfo-based applications rather
  //    than the 4 7  mode.
  //    Ps = 1 0 5 0  -> Reset terminfo/termcap function-key mode.
  //    Ps = 1 0 5 1  -> Reset Sun function-key mode.
  //    Ps = 1 0 5 2  -> Reset HP function-key mode.
  //    Ps = 1 0 5 3  -> Reset SCO function-key mode.
  //    Ps = 1 0 6 0  -> Reset legacy keyboard emulation (X11R6).
  //    Ps = 1 0 6 1  -> Reset keyboard emulation to Sun/PC style.
  //    Ps = 2 0 0 4  -> Reset bracketed paste mode.
  //
  csiDECRESET(int par, String collect) {
    if (collect == "") {
      switch (par) {
        case 4:
          this.insertMode = false;
          break;
        case 20:
          this.lineFeedMode = true;
          break;
      }
    } else if (collect == "?") {
      switch (par) {
        case 1:
          this.applicationCursor = false;
          break;
        case 3:
          if (this.allow80To132) {
            this.resize(80, this.rows);
            this.delegate.sizeChanged(this);
            this.reset();
            this.notifyListeners();
          }
          break;
        case 5:
          // Reset default color
          this.curAttr = CharData.DefaultAttr;
          break;
        case 6:
          this.originMode = false;
          break;
        case 7:
          this.wraparound = false;
          break;
        case 12:
          // this.cursorBlink = false;
          break;
        case 40:
          this.allow80To132 = false;
          break;
        case 45:
          this.reverseWraparound = false;
          break;
        case 66:
          this.log("Switching back to normal keypad.");
          this.applicationKeypad = false;
          this.syncScrollArea();
          break;
        case 69:
          // DECSLRM
          this.marginMode = false;
          break;
        case 9: // X10 Mouse
        case 1000: // vt200 mouse
        case 1002: // button event mouse
        case 1003: // any event mouse
          this.mouseMode = MouseMode.Off;
          break;
        case 1004: // send focusin/focusout events
          this.sendFocus = false;
          break;
        case 1005: // utf8 ext mode mouse
          if (this.mouseProtocol == MouseProtocolEncoding.UTF8) {
            this.mouseProtocol = MouseProtocolEncoding.X10;
          }
          break;
        case 1006: // sgr ext mode mouse
          if (this.mouseProtocol == MouseProtocolEncoding.SGR) {
            this.mouseProtocol = MouseProtocolEncoding.X10;
          }
          break;
        case 1015: // urxvt ext mode mouse
          if (this.mouseProtocol == MouseProtocolEncoding.URXVT) {
            this.mouseProtocol = MouseProtocolEncoding.X10;
          }
          break;
        case 25: // hide cursor
          this.cursorHidden = true;
          break;
        case 1048: // alt screen cursor
          this.restoreCursor();
          break;
        case 1049: // alt screen buffer cursor
        case 47: // normal screen buffer
        case 1047: // normal screen buffer - clearing it first
          // Ensure the selection manager has the correct buffer
          this.buffers.activateNormalBuffer(par == 1047);
          if (par == 1049) this.restoreCursor();
          this.refresh(0, this.rows - 1);
          this.syncScrollArea();
          this.showCursor();
          break;
        case 2004: // bracketed paste mode (https://cirw.in/blog/bracketed-paste)
          this.bracketedPasteMode = false;
          break;
      }
    }
  }
}
