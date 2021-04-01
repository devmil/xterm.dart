import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:platform_info/platform_info.dart';
import 'package:xterm/frontend/input_behavior.dart';
import 'package:xterm/frontend/input_map.dart';
import 'package:xterm/input/keyboard_translations.dart';
import 'package:xterm/xterm.dart';

class InputBehaviorDefault extends InputBehavior {
  const InputBehaviorDefault();

  @override
  bool get acceptKeyStroke => true;

  @override
  TextEditingValue get initEditingState => TextEditingValue.empty;

  @override
  void onKeyStroke(RawKeyEvent event, Terminal terminal) {
    if (event is! RawKeyDownEvent) {
      return;
    }

    final key = inputMap(event.logicalKey);

    if (key != null) {
      final sequence = KeyboardTranslations.getKeySequence(
          key,
          event.isControlPressed,
          event.isShiftPressed,
          event.isAltPressed,
          Platform.I.isMacOS,
          terminal.buffers.isAlternateBuffer);
      if (sequence != null) {
        terminal.delegate.send(sequence);
        return;
      }
    }
    //the key has no special handling => send it
    final runes = event.character?.runes.toList(growable: false);
    if (runes != null) {
      terminal.delegate.send(Uint8List.fromList(runes));
    }
  }

  @override
  TextEditingValue? onTextEdit(TextEditingValue value, Terminal terminal) {
    //TODO: preedit detection?
    //terminal.onInput(value.text);
    if (value == TextEditingValue.empty) {
      return null;
    } else {
      return TextEditingValue.empty;
    }
  }

  @override
  void onAction(TextInputAction action, Terminal terminal) {
    //
  }
}
