import 'dart:math';

import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/buffer/char_data.dart';
import 'package:xterm/terminal/terminal.dart';

extension TerminalBufferManipulationCommandExtensions on Terminal {
  /// <summary>
  /// DECERA - Erase Rectangular Area
  /// CSI Pt ; Pl ; Pb ; Pr ; $ z
  /// </summary>
  csiDECERA(List<int> pars) {
    var rect = getRectangleFromRequestPars(buffer, originMode, 0, pars);

    if (rect.valid) {
      for (int row = rect.top; row <= rect.bottom; row++) {
        var line = buffer.lines[row + buffer.yBase];
        for (int col = rect.left; col <= rect.right; col++) {
          line![col] = CharData(curAttr, rune: ' ', width: 1, code: 32);
        }
      }
    }
  }

  /// <summary>
  /// DECSERA - Selective Erase Rectangular Area
  /// CSI Pt ; Pl ; Pb ; Pr ; $ {
  /// </summary>
  csiDECSERA(List<int> pars) {
    var rect = getRectangleFromRequestPars(buffer, originMode, 0, pars);

    if (rect.valid) {
      for (int row = rect.top; row <= rect.bottom; row++) {
        var line = buffer.lines[row + buffer.yBase];
        for (int col = rect.left; col <= rect.right; col++) {
          line![col] = CharData(curAttr, rune: ' ', width: 1, code: 32);
        }
      }
    }
  }

  /// <summary>
  /// CSI Pc ; Pt ; Pl ; Pb ; Pr $ x Fill Rectangular Area (DECFRA), VT420 and up.
  /// </summary>
  csiDECFRA(List<int> pars) {
    var rect = getRectangleFromRequestPars(buffer, originMode, 1, pars);

    if (rect.valid) {
      String fillChar = ' ';
      if (pars.length > 0) {
        fillChar = String.fromCharCode(pars[0]);
      }

      for (int row = rect.top; row <= rect.bottom; row++) {
        var line = buffer.lines[row + buffer.yBase];
        for (int col = rect.left; col <= rect.right; col++) {
          line![col] = CharData(curAttr,
              rune: fillChar, width: 1, code: fillChar.codeUnitAt(0));
        }
      }
    }
  }

  /// <summary>
  /// Copy Rectangular Area (DECCRA), VT400 and up.
  /// CSI Pts ; Pls ; Pbs ; Prs ; Pps ; Ptd ; Pld ; Ppd $ v
  ///  Pts ; Pls ; Pbs ; Prs denotes the source rectangle.
  ///  Pps denotes the source page.
  ///  Ptd ; Pld denotes the target location.
  ///  Ppd denotes the target page.
  /// </summary>
  csiDECCRA(List<int> pars, String collect) {
    if (collect == "\$") {
      var parArray = [
        (pars.length > 1 && pars[0] != 0 ? pars[0] : 1), // Pts default 1
        (pars.length > 2 && pars[1] != 0 ? pars[1] : 1), // Pls default 1
        (pars.length > 3 && pars[2] != 0
            ? pars[2]
            : buffer.rows - 1), // Pbs default to last line of page
        (pars.length > 4 && pars[3] != 0
            ? pars[3]
            : buffer.cols - 1), // Prs defaults to last column
        (pars.length > 5 && pars[4] != 0 ? pars[4] : 1), // Pps page source = 1
        (pars.length > 6 && pars[5] != 0 ? pars[5] : 1), // Ptd default is 1
        (pars.length > 7 && pars[6] != 0 ? pars[6] : 1), // Pld default is 1
        (pars.length > 8 && pars[7] != 0 ? pars[7] : 1) // Ppd default is 1
      ];

      // We only support copying on the same page, and the page being 1
      if (parArray[4] == parArray[7] && parArray[4] == 1) {
        var rect = getRectangleFromRequestPars(buffer, originMode, 0, parArray);
        if (rect.valid) {
          var rowTarget = parArray[5] - 1;
          var colTarget = parArray[6] - 1;

          // Block size
          var columns = rect.right - rect.left + 1;

          var cright = min(buffer.cols - 1,
              rect.left + min(columns, buffer.cols - colTarget));

          var lines = List<BufferLine>.empty(growable: true);
          for (int row = rect.top; row <= rect.bottom; row++) {
            var line = buffer.lines[row + buffer.yBase];
            var lineCopy = BufferLine.createFrom(line!);
            lineCopy.isWrapped = false;
            lines.add(lineCopy);
          }

          for (int row = 0; row <= rect.bottom - rect.top; row++) {
            if (row + rowTarget >= buffer.rows) {
              break;
            }

            var line = buffer.lines[row + rowTarget + buffer.yBase];
            var lr = lines[row];
            for (int col = 0; col <= cright - rect.left; col++) {
              if (col >= buffer.cols) {
                break;
              }

              line![colTarget + col] = lr[col];
            }
          }
        }
      }
    }
  }

  /// <summary>
  /// Required by the test suite
  /// CSI Pi ; Pg ; Pt ; Pl ; Pb ; Pr * y
  /// Request Checksum of Rectangular Area (DECRQCRA), VT420 and up.
  /// Response is
  /// DCS Pi ! ~ x x x x ST
  ///   Pi is the request id.
  ///   Pg is the page number.
  ///   Pt ; Pl ; Pb ; Pr denotes the rectangle.
  ///   The x's are hexadecimal digits 0-9 and A-F.
  /// </summary>
  csiDECRQCRA(List<int> pars) {
    int checksum = 0;
    var rid = pars.length > 0 ? pars[0] : 1;
    var _ = pars.length > 1 ? pars[1] : 0;
    var result = "0000";

    // Still need to imeplemnt the checksum here
    // Which is just the sum of the rune values
    if (delegate.isProcessTrusted()) {
      var rect = getRectangleFromRequestPars(buffer, originMode, 2, pars);

      var top = rect.top;
      var left = rect.left;
      var bottom = rect.bottom;
      var right = rect.right;

      for (int row = top; row <= bottom; row++) {
        var line = buffer.lines[row + buffer.yBase];
        for (int col = left; col <= right; col++) {
          var cd = line![col];

          //var ch = cd.getCharacter ();
          //for (scalar in ch.unicodeScalars) {
          //	checksum += scalar.value;
          //}
          checksum += cd.code == 0 ? 32 : cd.code;
        }
      }
      result = checksum.toRadixString(16).padLeft(4, '0');
    }

    sendResponse("${controlCodes.dcs}${rid}!~${result}${controlCodes.st}");
  }

  /// <summary>
  /// Validates optional arguments for top, left, bottom, right sent by various
  /// escape sequences and returns validated top, left, bottom, right in our 0-based
  /// internal coordinates
  /// </summary>
  static TerminalRectangle getRectangleFromRequestPars(
      Buffer buffer, bool originMode, int start, List<int> pars) {
    var top = max(1, pars.length > start ? pars[start] : 1);
    var left = max(pars.length > start + 1 ? pars[start + 1] : 1, 1);
    var bottom = pars.length > start + 2 ? pars[start + 2] : -1;
    var right = pars.length > start + 3 ? pars[start + 3] : -1;

    var rect = getRectangleFromRequestValues(
        buffer, originMode, top, left, bottom, right);
    return rect;
  }

  /// <summary>
  /// Validates optional arguments for top, left, bottom, right sent by various
  /// escape sequences and returns validated top, left, bottom, right in our 0-based
  /// internal coordinates
  /// </summary>
  static TerminalRectangle getRectangleFromRequestValues(Buffer buffer,
      bool originMode, int top, int left, int bottom, int right) {
    if (bottom < 0) {
      bottom = buffer.rows;
    }
    if (right < 0) {
      right = buffer.cols;
    }
    if (right > buffer.cols) {
      right = buffer.cols;
    }
    if (bottom > buffer.rows) {
      bottom = buffer.rows;
    }
    if (originMode) {
      top += buffer.scrollTop;
      bottom += buffer.scrollTop;
      left += buffer.marginLeft;
      right += buffer.marginLeft;
    }

    if (top > bottom || left > right) {
      return TerminalRectangle(false, 0, 0, 0, 0);
    }

    return TerminalRectangle(true, top - 1, left - 1, bottom - 1, right - 1);
  }
}

class TerminalRectangle {
  bool valid;
  int top;
  int left;
  int bottom;
  int right;

  TerminalRectangle(this.valid, this.top, this.left, this.bottom, this.right);
}
