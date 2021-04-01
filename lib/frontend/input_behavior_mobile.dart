import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/frontend/input_behavior_default.dart';
import 'package:xterm/input/keyboard_translations.dart';
import 'package:xterm/input/keys.dart';
import 'package:xterm/xterm.dart';

class InputBehaviorMobile extends InputBehaviorDefault {
  const InputBehaviorMobile();

  final acceptKeyStroke = false;

  final initEditingState = const TextEditingValue(
    text: '  ',
    selection: TextSelection.collapsed(offset: 1),
  );

  TextEditingValue onTextEdit(TextEditingValue value, Terminal terminal) {
    if (value.text.length > initEditingState.text.length) {
      final sequence = value.text
          .substring(1, value.text.length - 1)
          .runes
          .toList(growable: false);
      terminal.delegate.send(Uint8List.fromList(sequence));
    } else if (value.text.length < initEditingState.text.length) {
      final sequence = KeyboardTranslations.getKeySequence(
          TerminalKey.backspace,
          false,
          false,
          false,
          false,
          terminal.buffers.isAlternateBuffer);
      if (sequence != null) {
        terminal.delegate.send(sequence);
      }
    } else {
      TerminalKey? keyToSend;
      if (value.selection.baseOffset < 1) {
        keyToSend = TerminalKey.arrowLeft;
      } else if (value.selection.baseOffset > 1) {
        keyToSend = TerminalKey.arrowRight;
      }
      if (keyToSend != null) {
        final sequence = KeyboardTranslations.getKeySequence(keyToSend, false,
            false, false, false, terminal.buffers.isAlternateBuffer);
        if (sequence != null) {
          terminal.delegate.send(sequence);
        }
      }
    }

    return initEditingState;
  }

  void onAction(TextInputAction action, Terminal terminal) {
    print('action $action');
    switch (action) {
      case TextInputAction.done:
        final sequence = KeyboardTranslations.getKeySequence(TerminalKey.enter,
            false, false, false, false, terminal.buffers.isAlternateBuffer);
        if (sequence != null) {
          terminal.delegate.send(sequence);
        }
        break;
      default:
        print('unknown action $action');
    }
  }
}
