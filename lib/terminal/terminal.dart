import 'package:xterm/terminal/terminal_options.dart';

class Terminal {
  int get cols => 0;
  int get rows => 0;

  final _options = TerminalOptions();

  TerminalOptions get options => _options;
  bool get marginMode => false;
}
