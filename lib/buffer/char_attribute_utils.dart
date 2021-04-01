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
  static int getFgColor(int attribute) {
    return (attribute >> 9) & 0x1ff;
  }

  static int getBgColor(int attribute) {
    return attribute & 0x1ff;
  }

  static bool isBold(int attribute) {
    var ca = (attribute >> 18);
    return CharAttributeFlagsExtensions.intHasFlag(ca, CharAttributeFlags.Bold);
  }

  static bool isItalic(int attribute) {
    var ca = (attribute >> 18);
    return CharAttributeFlagsExtensions.intHasFlag(
        ca, CharAttributeFlags.Italic);
  }

  static bool isUnderline(int attribute) {
    var ca = (attribute >> 18);
    return CharAttributeFlagsExtensions.intHasFlag(
        ca, CharAttributeFlags.Underline);
  }

  static bool isBlink(int attribute) {
    var ca = (attribute >> 18);
    return CharAttributeFlagsExtensions.intHasFlag(
        ca, CharAttributeFlags.Blink);
  }

  static bool isInverse(int attribute) {
    var ca = (attribute >> 18);
    return CharAttributeFlagsExtensions.intHasFlag(
        ca, CharAttributeFlags.Inverse);
  }

  static bool isInvisible(int attribute) {
    var ca = (attribute >> 18);
    return CharAttributeFlagsExtensions.intHasFlag(
        ca, CharAttributeFlags.Invisible);
  }

  static bool isDim(int attribute) {
    var ca = (attribute >> 18);
    return CharAttributeFlagsExtensions.intHasFlag(ca, CharAttributeFlags.Dim);
  }

  static String toSGR(int attribute) {
    var result = '0';

    var ca = (attribute >> 18);
    if (isBold(attribute)) {
      result += ';1';
    }
    if (isUnderline(attribute)) {
      result += ';4';
    }
    if (isBlink(attribute)) {
      result += ';5';
    }
    if (isInverse(attribute)) {
      result += ';7';
    }
    if (isInvisible(attribute)) {
      result += ';8';
    }

    int fg = getFgColor(attribute);

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

    int bg = getBgColor(attribute);
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
