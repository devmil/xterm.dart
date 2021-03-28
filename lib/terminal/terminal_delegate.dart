import 'dart:typed_data';

import 'package:xterm/terminal/window_manipulation_command.dart';
import 'package:xterm/xterm.dart';

abstract class TerminalDelegate {
  showCursor(Terminal source);
  setTerminalTitle(Terminal source, String title);
  setTerminalIconTitle(Terminal source, String iconTitle);
  sizeChanged(Terminal source);
  send(Uint8List data);
  String? windowCommand(
      Terminal source, WindowManipulationCommand command, List<int> args);
  bool isProcessTrusted();
}

class DummyTerminalDelegate extends TerminalDelegate {
  @override
  bool isProcessTrusted() {
    return true;
  }

  @override
  send(Uint8List data) {}

  @override
  setTerminalIconTitle(Terminal source, String iconTitle) {}

  @override
  setTerminalTitle(Terminal source, String title) {}

  @override
  showCursor(Terminal source) {}

  @override
  sizeChanged(Terminal source) {}

  @override
  String? windowCommand(
      Terminal source, WindowManipulationCommand command, List<int> args) {
    return null;
  }
}
