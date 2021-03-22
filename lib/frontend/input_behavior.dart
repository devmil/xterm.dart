import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/terminal/terminal_ui_interaction.dart';

abstract class InputBehavior {
  const InputBehavior();

  bool get acceptKeyStroke;

  TextEditingValue get initEditingState;

  void onKeyStroke(RawKeyEvent event, TerminalUiInteraction terminal);

  TextEditingValue? onTextEdit(TextEditingValue value, TerminalUiInteraction terminal);

  void onAction(TextInputAction action, TerminalUiInteraction terminal);
}
