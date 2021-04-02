class TerminalOptions {
  int scrollback = 5000;
  int get tabStopWidth => 8;
  int cols = 80;
  int rows = 25;
  bool get convertEol => true;
  String get termName => 'Term';
  bool get screenReaderMode => false;
}

enum CursorStyle {
  BlinkBlock,
  SteadyBlock,
  BlinkUnderline,
  SteadyUnderline,
  BlinkingBar,
  SteadyBar
}
