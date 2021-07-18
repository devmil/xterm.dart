import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/frontend/input_behavior.dart';
import 'package:xterm/frontend/input_map.dart';
import 'package:xterm/xterm.dart';

class InputBehaviorDefault extends InputBehavior {
  InputBehaviorDefault();

  @override
  bool get acceptKeyStroke => true;

  @override
  TextEditingValue get initEditingState => TextEditingValue.empty;

  @override
  void onKeyStroke(RawKeyEvent event, TerminalUiInteraction terminal) {
    if (event is! RawKeyDownEvent) {
      return;
    }

    final key = inputMap(event.logicalKey);

    if (key != null) {
      terminal.keyInput(
        key,
        ctrl: event.isControlPressed,
        alt: event.isAltPressed,
        shift: event.isShiftPressed,
        mac: terminal.platform.useMacInputBehavior,
      );
    }
  }

  String? _composingString = null;
  String? _ignoreChar;

  @override
  TextEditingValue? onTextEdit(
      TextEditingValue value, TerminalUiInteraction terminal) {
    var inputText = value.text;
    //print('INPUT: "${value.text}" ${value.composing} | ${value.selection}');
    // we just want to detect if a composing is going on and notify the terminal
    // about it
    if (value.composing.start != value.composing.end) {
      _composingString = inputText;
      terminal.updateComposingString(_composingString!);
      return null;
    }
    if (_ignoreChar != null && inputText != '') {
      if (inputText.startsWith(_ignoreChar!)) {
        inputText = inputText.substring(_ignoreChar!.length);
      }
      _ignoreChar = null;
    }
    if (_composingString != null) {
      // we ignore the just committed string the next time
      // as the input system sends it again together with
      // the next character
      _ignoreChar = _composingString;
      _composingString = null;
      terminal.updateComposingString('');
    }

    terminal.raiseOnInput(inputText);

    if (value == TextEditingValue.empty || inputText == '') {
      return null;
    } else {
      return TextEditingValue.empty;
    }
  }

  @override
  void onAction(TextInputAction action, TerminalUiInteraction terminal) {
    //
  }
}
