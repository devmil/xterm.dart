import 'dart:convert';
import 'dart:typed_data';

import 'package:xterm/input/keyboard_translation.dart';

/// <summary>
/// Provides static data for translating keystrokes from textual format to VT100... format
/// </summary>
class KeyboardTranslations {
  /// <summary>
  /// Translates a key sequence from text to DEC VT byte codes
  /// </summary>
  /// <param name="key">The key formatted as text as seen in the dictionary below.</param>
  /// <param name="control">Determines if the control key is pressed</param>
  /// <param name="shift">Determines if the shift key is pressed</param>
  /// <param name="alt">Determines if the alt key is pressed</param>
  /// <param name="mac">Determines if we want to behave like a MAC</param>
  /// <param name="applicationMode">Set to true if the application mode mapping is desired</param>
  /// <returns></returns>
  static Uint8List? getKeySequence(String key, bool control, bool shift,
      bool alt, bool mac, bool applicationMode) {
    final translation = _translations[key];
    if (translation != null) {
      if (translation.translateFunc != null) {
        return translation.translateFunc!
                (shift, control, alt, mac, applicationMode)
            .to8();
      }

      if (applicationMode && (translation.applicationMode ?? '') != '')
        return translation.applicationMode?.to8();

      if (shift) {
        return translation.shift?.to8();
      }

      if (alt) {
        return translation.alt?.to8();
      }

      if (control) {
        return translation.control?.to8();
      }

      return translation.normal?.to8();
    }

    return null;
  }

  static String _buildKeyCode(
      bool shift, bool control, bool alt, bool mac, bool app, bool left) {
    var modifiers = (shift ? 1 : 0) | (alt ? 2 : 0) | (control ? 4 : 0);

    String result;

    var keyIdentifier = left ? "D" : "C";

    if (modifiers != 0) {
      result = "\u001b[1;${modifiers + 1}$keyIdentifier";
      if (modifiers == 2) {
        //Hack for Linux (5) and Mac (b/f)
        if (mac) {
          result = "\u001b${(left ? "b" : "f")}";
        } else {
          result = "\u001b[1;5$keyIdentifier";
        }
      }
    } else if (app) {
      result = "\u001bO$keyIdentifier";
    } else {
      result = "\u001b[$keyIdentifier";
    }

    return result;
  }

  static final _translations = <String, KeyboardTranslation>{
    // ## Function keys (Normal or Application Mode)
    // | Key    | Normal  | Shift   | Control   |
    // |--------|---------|---------|-----------|
    // | F1     | CSI 11~ | CSI 23~ | CSI 11~   |
    // | F2     | CSI 12~ | CSI 24~ | CSI 12~   |
    // | F3     | CSI 13~ | CSI 25~ | CSI 13~   |
    // | F4     | CSI 14~ | CSI 26~ | CSI 14~   |
    // | F5     | CSI 15~ | CSI 28~ | CSI 15~   |
    // | F6     | CSI 17~ | CSI 29~ | CSI 17~   |
    // | F7     | CSI 18~ | CSI 31~ | CSI 18~   |
    // | F8     | CSI 19~ | CSI 32~ | CSI 19~   |
    // | F9     | CSI 20~ | CSI 33~ | CSI 20~   |
    // | F10    | CSI 21~ | CSI 24~ | CSI 21~   |
    // | F11    | CSI 23~ | CSI 23~ | CSI 23~   |
    // | F12    | CSI 24~ | CSI 24~ | CSI 24~   |
    'F1': KeyboardTranslation(
        normal: '\u001bOP', shift: '\u001b[23~', control: '\u001b[11~'),
    'F2': KeyboardTranslation(
        normal: '\u001bOQ', shift: '\u001b[24~', control: '\u001b[12~'),
    'F3': KeyboardTranslation(
        normal: '\u001bOR', shift: '\u001b[25~', control: '\u001b[13~'),
    'F4': KeyboardTranslation(
        normal: '\u001bOS', shift: '\u001b[26~', control: '\u001b[14~'),
    'F5': KeyboardTranslation(
        normal: '\u001b[15~', shift: '\u001b[28~', control: '\u001b[15~'),
    'F6': KeyboardTranslation(
        normal: '\u001b[17~', shift: '\u001b[29~', control: '\u001b[17~'),
    'F7': KeyboardTranslation(
        normal: '\u001b[18~', shift: '\u001b[31~', control: '\u001b[18~'),
    'F8': KeyboardTranslation(
        normal: '\u001b[19~', shift: '\u001b[32~', control: '\u001b[19~'),
    'F9': KeyboardTranslation(
        normal: '\u001b[20~', shift: '\u001b[33~', control: '\u001b[20~'),
    'F10': KeyboardTranslation(
        normal: '\u001b[21~', shift: '\u001b[24~', control: '\u001b[21~'),
    'F11': KeyboardTranslation(
        normal: '\u001b[23~', shift: '\u001b[23~', control: '\u001b[23~'),
    'F12': KeyboardTranslation(
        normal: '\u001b[24~', shift: '\u001b[24~', control: '\u001b[24~'),

    // ## Arrow keys
    // | Key    | Normal | Shift  | Control  | Application |
    // |--------|--------|--------|----------|-------------|
    // | Up     | CSI A  | Esc OA | Esc OA   | Esc OA      |
    // | Down   | CSI B  | Esc OB | Esc OB   | Esc OB      |
    // | Right  | CSI C  | Esc OC | Esc OC   | Esc OC      |
    // | Left   | CSI D  | Esc OD | Esc OD   | Esc OD      |
    // | Home   | CSI 1~ | CSI 1~ |          | CSI 1~      |
    // | Ins    | CSI 2~ |        |          | CSI 2~      |
    // | Del    | CSI 3~ | CSI 3~ |          | CSI 3~      |
    // | End    | CSI 4~ | CSI 4~ |          | CSI 4~      |
    // | PgUp   | CSI 5~ | CSI 5~ |          | CSI 5~      |
    // | PgDn   | CSI 6~ | CSI 6~ |          | CSI 6~      |
    'Up': KeyboardTranslation(
        normal: '\u001b[A',
        shift: '\u001bOA',
        control: '\u001bOA',
        applicationMode: '\u001bOA'),
    'Down': KeyboardTranslation(
        normal: '\u001b[B',
        shift: '\u001bOB',
        control: '\u001bOB',
        applicationMode: '\u001bOB'),
    'Right': KeyboardTranslation(
        translateFunc: (s, c, a, m, app) =>
            _buildKeyCode(s, c, a, m, app, false)),
    'Left': KeyboardTranslation(
        translateFunc: (s, c, a, m, app) =>
            _buildKeyCode(s, c, a, m, app, true)),
    'Home': KeyboardTranslation(normal: '\u001b[1~', shift: '\u001b[1~'),
    'Insert': KeyboardTranslation(normal: '\u001b[2~'),
    'Delete': KeyboardTranslation(normal: '\u001b[3~', shift: '\u001b[3~'),
    'End': KeyboardTranslation(normal: '\u001b[4~', shift: '\u001b[4~'),
    'PageUp': KeyboardTranslation(normal: '\u001b[5~', shift: '\u001b[5~'),
    'PageDown': KeyboardTranslation(normal: '\u001b[6~', shift: '\u001b[6~'),

    // ## Number Keys (No num lock)
    // | Key       | Normal | Shift  | NumLock |
    // |-----------|--------|--------|---------|
    // | 0 (Ins)   | CSI 2~ |        | 0       |
    // | . (Del)   | CSI 3~ | CSI 3~ | .       |
    // | 1 (End)   | CSI 4~ | CSI 4~ | 1       |
    // | 2 (Down)  | CSI B  | ESC OB | 2       |
    // | 3 (PgDn)  | CSI 6~ |        | 3       |
    // | 4 (Left)  | CSI D  | Esc OD | 4       |
    // | 5         | CSI G  | Esc OG | 5       |
    // | 6 (Right) | CSI C  | Esc OC | 6       |
    // | 7 (Home)  | CSI 1~ | CSI 1~ | 7       |
    // | 8 (Up)    | CSI A  | Esc OA | 8       |
    // | 9 (PgUp)  | CSI 5~ |        | 9       |
    // | /         | /      | /      | /       |
    // | *         | *      | *      | *       |
    // | -         | -      | -      | -       |
    // | +         | +      | +      | +       |
    // | Enter     | \r\n   | \r\n   | \r\n    |

    // ## Main keyboard
    // | Key    | Normal | Shift  | Control  |
    // |--------|--------|--------|----------|
    // | Bksp   | \x7F   | \b     | \x7f     |
    // | Tab    | \t     | CSI Z  |          |
    // | Enter  | \r\n   | \r\n   | \r\n     |
    // | Esc    | Esc    | Esc    | Esc      |
    // | A      | a      | A      | \x01     |
    // | B      | b      | B      | \x02     |
    // | C      | c      | C      | \x03     |
    // | D      | d      | D      | \x04     |
    // | E      | e      | E      | \x05     |
    // | F      | f      | F      | \x06     |
    // | G      | g      | G      | \x07     |
    // | H      | h      | H      | \x08     |
    // | I      | i      | I      | \x09     |
    // | J      | j      | J      | \x0a     |
    // | K      | k      | K      | \x0b     |
    // | L      | l      | L      | \x0c     |
    // | M      | m      | M      | \x0d     |
    // | N      | n      | N      | \x0e     |
    // | O      | o      | O      | \x0f     |
    // | P      | p      | P      | \x10     |
    // | Q      | q      | Q      | \x11     |
    // | R      | r      | R      | \x12     |
    // | S      | s      | S      | \x13     |
    // | T      | t      | T      | \x14     |
    // | U      | u      | U      | \x15     |
    // | V      | v      | V      | \x16     |
    // | W      | w      | W      | \x17     |
    // | X      | x      | X      | \x18     |
    // | Y      | y      | Y      | \x19     |
    // | Z      | z      | Z      | \x1a     |
    'Back':
        KeyboardTranslation(normal: '\u007F', shift: '\b', control: '\u007F'),
    'Tab': KeyboardTranslation(normal: '\t', shift: '\u001b[Z'),
    'Enter': KeyboardTranslation(
        normal: '\n', shift: '\n', control: '\n', alt: '\u001b\n'),
    'Return': KeyboardTranslation(
        normal: '\r', shift: '\r', control: '\r', alt: '\u001b\r'),
    'Escape': KeyboardTranslation(
        normal: '\u001b',
        shift: '\u001b\u001b',
        control: '\u001b\u001b',
        alt: '\u001b\u001b'),
    'A': KeyboardTranslation(control: '\u0001'),
    'B': KeyboardTranslation(control: '\u0002'),
    'C': KeyboardTranslation(control: '\u0003'),
    'D': KeyboardTranslation(control: '\u0004'),
    'E': KeyboardTranslation(control: '\u0005'),
    'F': KeyboardTranslation(control: '\u0006'),
    'G': KeyboardTranslation(control: '\u0007'),
    'H': KeyboardTranslation(control: '\u0008'),
    'I': KeyboardTranslation(control: '\u0009'),
    'J': KeyboardTranslation(control: '\u000a'),
    'K': KeyboardTranslation(control: '\u000b'),
    'L': KeyboardTranslation(control: '\u000c'),
    'M': KeyboardTranslation(control: '\u000d'),
    'N': KeyboardTranslation(control: '\u000e'),
    'O': KeyboardTranslation(control: '\u000f'),
    'P': KeyboardTranslation(control: '\u0010'),
    'Q': KeyboardTranslation(control: '\u0011'),
    'R': KeyboardTranslation(control: '\u0012'),
    'S': KeyboardTranslation(control: '\u0013'),
    'T': KeyboardTranslation(control: '\u0014'),
    'U': KeyboardTranslation(control: '\u0015'),
    'V': KeyboardTranslation(control: '\u0016'),
    'W': KeyboardTranslation(control: '\u0017'),
    'X': KeyboardTranslation(control: '\u0018'),
    'Y': KeyboardTranslation(control: '\u0019'),
    'Z': KeyboardTranslation(control: '\u001a'),
    'a': KeyboardTranslation(control: '\u0001'),
    'b': KeyboardTranslation(control: '\u0002'),
    'c': KeyboardTranslation(control: '\u0003'),
    'd': KeyboardTranslation(control: '\u0004'),
    'e': KeyboardTranslation(control: '\u0005'),
    'f': KeyboardTranslation(control: '\u0006'),
    'g': KeyboardTranslation(control: '\u0007'),
    'h': KeyboardTranslation(control: '\u0008'),
    'i': KeyboardTranslation(control: '\u0009'),
    'j': KeyboardTranslation(control: '\u000a'),
    'k': KeyboardTranslation(control: '\u000b'),
    'l': KeyboardTranslation(control: '\u000c'),
    'm': KeyboardTranslation(control: '\u000d'),
    'n': KeyboardTranslation(control: '\u000e'),
    'o': KeyboardTranslation(control: '\u000f'),
    'p': KeyboardTranslation(control: '\u0010'),
    'q': KeyboardTranslation(control: '\u0011'),
    'r': KeyboardTranslation(control: '\u0012'),
    's': KeyboardTranslation(control: '\u0013'),
    't': KeyboardTranslation(control: '\u0014'),
    'u': KeyboardTranslation(control: '\u0015'),
    'v': KeyboardTranslation(control: '\u0016'),
    'w': KeyboardTranslation(control: '\u0017'),
    'x': KeyboardTranslation(control: '\u0018'),
    'y': KeyboardTranslation(control: '\u0019'),
    'z': KeyboardTranslation(control: '\u001a'),
  };
}

extension _StringU8Extension on String {
  static final _utf8Encoder = Utf8Encoder();

  Uint8List to8() {
    return _utf8Encoder.convert(this);
  }
}
