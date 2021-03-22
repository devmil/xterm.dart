import 'package:xterm/input/keys.dart';
import 'package:xterm/mouse/position.dart';

abstract class TerminalUiInteraction {
  void refresh();
  void clearSelection();
  void onMouseTap(Position position);
  void onPanStart(Position position);
  void onPanUpdate(Position position);
  void setScrollOffsetFromBottom(int offset);
  int convertViewLineToRawLine(int viewLine);
  void raiseOnInput(String input);
  void write(String text);
  void paste(String data);
  void resize(int newWidth, int newHeight);
  void keyInput(
    TerminalKey key, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
    // bool meta,
  });
}
