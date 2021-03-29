import 'package:xterm/renderer/renderer.dart';

enum CharAttributeFlags {
  Bold,
  Underline,
  Blink,
  Inverse,
  Invisible,
  Dim,
  Italic,
  CrossedOut
}

extension CharAttributeFlagsExtensions on CharAttributeFlags {
  static Map<CharAttributeFlags, int> _enumToValueMap = {
    CharAttributeFlags.Bold: 1,
    CharAttributeFlags.Underline: 2,
    CharAttributeFlags.Blink: 4,
    CharAttributeFlags.Inverse: 8,
    CharAttributeFlags.Invisible: 16,
    CharAttributeFlags.Dim: 32,
    CharAttributeFlags.Italic: 64,
    CharAttributeFlags.CrossedOut: 128
  };
  static Map<int, CharAttributeFlags>? _valueToEnumMap;

  static _ensureInitialized() {
    if (CharAttributeFlagsExtensions._valueToEnumMap == null) {
      CharAttributeFlagsExtensions._valueToEnumMap =
          Map<int, CharAttributeFlags>();
      for (final e in CharAttributeFlagsExtensions._enumToValueMap.entries) {
        CharAttributeFlagsExtensions._valueToEnumMap![e.value] = e.key;
      }
    }
  }

  int get value {
    CharAttributeFlagsExtensions._ensureInitialized();
    return CharAttributeFlagsExtensions._enumToValueMap[this]!;
  }

  static bool intHasFlag(int value, CharAttributeFlags flag) {
    return value & flag.value != 0;
  }
}

class CharAttributeUtils {
  static String toSGR(int attribute) {
    var result = '0';

    var ca = (attribute >> 18);
    if (CharAttributeFlagsExtensions.intHasFlag(ca, CharAttributeFlags.Bold)) {
      result += ';1';
    }
    if (CharAttributeFlagsExtensions.intHasFlag(
        ca, CharAttributeFlags.Underline)) {
      result += ';4';
    }
    if (CharAttributeFlagsExtensions.intHasFlag(ca, CharAttributeFlags.Blink)) {
      result += ';5';
    }
    if (CharAttributeFlagsExtensions.intHasFlag(
        ca, CharAttributeFlags.Inverse)) {
      result += ';7';
    }
    if (CharAttributeFlagsExtensions.intHasFlag(
        ca, CharAttributeFlags.Invisible)) {
      result += ';8';
    }

    int fg = (attribute >> 9) & 0x1ff;

    if (fg != Renderer.DefaultColor) {
      if (fg > 16) {
        result += ';38;5;$fg';
      } else {
        if (fg >= 8) {
          result += ';{9}${fg - 8};';
        } else {
          result += ';{3}$fg;';
        }
      }
    }

    int bg = attribute & 0x1ff;
    if (bg != Renderer.DefaultColor) {
      if (bg > 16) {
        result += ';48;5;$bg';
      } else {
        if (bg >= 8) {
          result += ';{10}${bg - 8};';
        } else {
          result += ';{4}$bg;';
        }
      }
    }

    result += 'm';
    return result;
  }
}
