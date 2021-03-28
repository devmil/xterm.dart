import 'dart:math';

import 'package:xterm/terminal/terminal.dart';
import 'package:xterm/terminal/window_manipulation_command.dart';

extension TerminalCommandExtensions on Terminal {
  /// <summary>
  // CSI Ps A
  // Cursor Up Ps Times (default = 1) (CUU).
  /// </summary>
  csiCUU(List<int> pars) {
    int param = max(pars.length > 0 ? pars[0] : 1, 1);
    this.cursorUp(param);
  }

  /// <summary>
  // CSI Ps B
  // Cursor Down Ps Times (default = 1) (CUD).
  /// </summary>
  csiCUD(List<int> pars) {
    int param = max(pars.length > 0 ? pars[0] : 1, 1);
    cursorDown(param);
  }

  /// <summary>
  // CSI Ps C
  // Cursor Forward Ps Times (default = 1) (CUF).
  /// </summary>
  csiCUF(List<int> pars) {
    int param = max(pars.length > 0 ? pars[0] : 1, 1);
    cursorForward(param);
  }

  /// <summary>
  /// CSI Ps D
  /// Cursor Backward Ps Times (default = 1) (CUB).
  /// </summary>
  csiCUB(List<int> pars) {
    int param = max(pars.length > 0 ? pars[0] : 1, 1);
    cursorBackward(param);
  }

  /// <summary>
  /// CSI Ps G
  /// Cursor Character Absolute  [column] (default = [row,1]) (CHA).
  /// </summary>
  csiCHA(List<int> pars) {
    int param = max(pars.length > 0 ? pars[0] : 1, 1);
    cursorCharAbsolute(param);
  }

  /// <summary>
  /// Sets the cursor position from csi CUP
  /// CSI Ps ; Ps H
  /// Cursor Position [row;column] (default = [1,1]) (CUP).
  /// </summary>
  csiCUP(List<int> pars) {
    int col, row;
    switch (pars.length) {
      case 1:
        row = pars[0] - 1;
        col = 0;
        break;
      case 2:
        row = pars[0] - 1;
        col = pars[1] - 1;
        break;
      default:
        col = 0;
        row = 0;
        break;
    }

    setCursor(col, row);
  }

  /// <summary>
  /// Deletes lines
  /// </summary>
  /// <remarks>
  // CSI Ps M
  // Delete Ps Line(s) (default = 1) (DL).
  /// </remarks>
  csiDL(List<int> pars) {
    var p = max(pars.length == 0 ? 1 : pars[0], 1);
    deleteLines(p);
  }

  /// <summary>
  /// CSI Ps P
  /// Delete Ps Character(s) (default = 1) (DCH).
  /// </summary>
  csiDCH(List<int> pars) {
    var p = max(pars.length == 0 ? 1 : pars[0], 1);
    deleteChars(p);
  }

  /// <summary>
  /// CSI Ps Z  Cursor Backward Tabulation Ps tabList<int> pars = 1) (CBT).
  /// </summary>
  csiCBT(List<int> pars) {
    var p = max(pars.length == 0 ? 1 : pars[0], 1);
    cursorBackwardTab(p);
  }

  /// <summary>
  /// Sets the margins from csi DECSLRM
  /// </summary>
  csiDECSLRM(List<int> pars) {
    var left = (pars.length > 0 ? pars[0] : 1) - 1;
    var right = (pars.length > 1 ? pars[1] : buffer.cols) - 1;

    buffer.setMargins(left, right);
  }

  /// <summary>
  /// CSI Ps ; Ps r
  ///   Set Scrolling Region [top;bottom] (default = full size of win-
  ///   dow) (DECSTBM).
  // CSI ? Pm r
  /// </summary>
  csiDECSTBM(List<int> pars) {
    final top = pars.length > 0 ? max(pars[0] - 1, 0) : 0;
    final bottom = pars.length > 1 ? pars[1] : 0;

    setScrollRegion(top, bottom);
  }

  /// <summary>
  /// CSI # }   Pop video attributes from stack (XTPOPSGR), xterm.  Popping
  ///           restores the video-attributes which were saved using XTPUSHSGR
  ///           to their previous state.
  ///
  /// CSI Pm ' }
  ///           Insert Ps Column(s) (default = 1) (DECIC), VT420 and up.
  /// </summary>
  csiDECIC(List<int> pars) {
    final n = pars.length > 0 ? max(pars[0], 1) : 1;
    insertColumn(n);
  }

  /// <summary>
  /// CSI Ps ' ~
  /// Delete Ps Column(s) (default = 1) (DECDC), VT420 and up.
  ///
  /// @vt: #Y CSI DECDC "Delete Columns"  "CSI Ps ' ~"  "Delete `Ps` columns at cursor position."
  /// DECDC deletes `Ps` times columns at the cursor position for all lines with the scroll margins,
  /// moving content to the left. Blank columns are added at the right margin.
  /// DECDC has no effect outside the scrolling margins.
  /// </summary>
  csiDECDC(List<int> pars) {
    final n = pars.length > 0 ? max(pars[0], 1) : 1;
    deleteColumn(n);
  }

  /// <summary>
  /// CSI Ps ; Ps ; Ps t - Various window manipulations and reports (xterm)
  /// See https://invisible-island.net/xterm/ctlseqs/ctlseqs.html for a full
  /// list of commans for this escape sequence
  /// </summary>
  csiDISPATCH(List<int>? pars) {
    if (pars == null || pars.length == 0) return;

    if (pars.length == 3 && pars[0] == 3) {
      delegate.windowCommand(
          this, WindowManipulationCommand.MoveWindowTo, [pars[1], pars[2]]);
      return;
    }
    if (pars.length == 3 && pars[0] == 4) {
      delegate.windowCommand(
          this, WindowManipulationCommand.MoveWindowTo, [pars[1], pars[2]]);
      return;
    }

    if (pars.length == 3 && pars[0] == 8) {
      delegate.windowCommand(
          this, WindowManipulationCommand.ResizeTo, [pars[1], pars[2]]);
      return;
    }

    if (pars.length == 2 && pars[0] == 9) {
      switch (pars[1]) {
        case 0:
          delegate.windowCommand(
              this, WindowManipulationCommand.RestoreMaximizedWindow, []);
          return;
        case 1:
          delegate.windowCommand(
              this, WindowManipulationCommand.MaximizeWindow, []);
          return;
        case 2:
          delegate.windowCommand(
              this, WindowManipulationCommand.MaximizeWindowVertically, []);
          return;
        case 3:
          delegate.windowCommand(
              this, WindowManipulationCommand.MaximizeWindowHorizontally, []);
          return;
        default:
          return;
      }
    }

    if (pars.length == 2 && pars[0] == 10) {
      switch (pars[1]) {
        case 0:
          delegate.windowCommand(
              this, WindowManipulationCommand.UndoFullScreen, []);
          return;
        case 1:
          delegate.windowCommand(
              this, WindowManipulationCommand.SwitchToFullScreen, []);
          return;
        case 2:
          delegate.windowCommand(
              this, WindowManipulationCommand.ToggleFullScreen, []);
          return;
        default:
          return;
      }
    }

    if (pars.length == 2 && pars[0] == 22) {
      switch (pars[1]) {
        case 0:
          pushTitle();
          pushIconTitle();
          return;
        case 1:
          pushIconTitle();
          return;
        case 2:
          pushTitle();
          return;
        default:
          return;
      }
    }

    if (pars.length == 2 && pars[0] == 23) {
      switch (pars[1]) {
        case 0:
          popTitle();
          popIconTitle();
          return;
        case 1:
          popTitle();
          return;
        case 2:
          popIconTitle();
          return;
        default:
          return;
      }
    }

    if (pars.length == 1) {
      switch (pars[0]) {
        case 0:
          delegate.windowCommand(
              this, WindowManipulationCommand.DeiconifyWindow, []);
          return;
        case 1:
          delegate
              .windowCommand(this, WindowManipulationCommand.IconifyWindow, []);
          return;
        case 2:
          return;
        case 3:
          return;
        case 4:
          return;
        case 5:
          delegate
              .windowCommand(this, WindowManipulationCommand.BringToFront, []);
          return;
        case 6:
          delegate
              .windowCommand(this, WindowManipulationCommand.SendToBack, []);
          return;
        case 7:
          delegate
              .windowCommand(this, WindowManipulationCommand.RefreshWindow, []);
          return;
        case 15:
          var response = delegate.windowCommand(
              this, WindowManipulationCommand.ReportSizeOfScreenInPixels, []);
          if (response == null) {
            response = '${controlCodes.csi}5;768;1024t';
          }
          sendResponse(response);
          return;
        case 16:
          var response = delegate.windowCommand(
              this, WindowManipulationCommand.ReportCellSizeInPixels, []);
          if (response == null) {
            response = '${controlCodes.csi}6;16;10t';
          }

          sendResponse(response);
          return;
        case 17:
          return;
        case 18:
          var response = delegate.windowCommand(
              this, WindowManipulationCommand.ReportScreenSizeCharacters, []);
          if (response == null) {
            response = '${controlCodes.csi}8;${rows};${cols}t';
          }

          sendResponse(response);
          return;
        case 19:
          var response = delegate.windowCommand(
              this, WindowManipulationCommand.ReportScreenSizeCharacters, []);
          if (response == null) {
            response = '${controlCodes.csi}9;${rows};${cols}t';
          }

          sendResponse(response);
          return;
        case 20:
          var response = iconTitle.replaceAll("\\", "");
          sendResponse('${controlCodes.osc}l${response}${controlCodes.st}');
          return;
        case 21:
          var response = title.replaceAll("\\", "");
          sendResponse('${controlCodes.osc}l${response}${controlCodes.st}');
          return;
        default:
          return;
      }
    }
  }
}
