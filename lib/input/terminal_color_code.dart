enum TerminalColorCode {
  Black,
  Red,
  Green,
  Yellow,
  Blue,
  Magenta,
  Cyan,
  White,
  BrightBlack,
  BrightRed,
  BrightGreen,
  BrightYellow,
  BrightBlue,
  BrightMagenta,
  BrightCyan,
  BrightWhite,
  Default,
}

extension TerminalColorCodeExtension on TerminalColorCode {
  static final _enumValueMap = <TerminalColorCode, int>{
    TerminalColorCode.Black: 0,
    TerminalColorCode.Red: 1,
    TerminalColorCode.Green: 2,
    TerminalColorCode.Yellow: 3,
    TerminalColorCode.Blue: 4,
    TerminalColorCode.Magenta: 5,
    TerminalColorCode.Cyan: 6,
    TerminalColorCode.White: 7,
    TerminalColorCode.Default: 9,
    TerminalColorCode.BrightBlack: 10,
    TerminalColorCode.BrightRed: 11,
    TerminalColorCode.BrightGreen: 12,
    TerminalColorCode.BrightYellow: 13,
    TerminalColorCode.BrightBlue: 14,
    TerminalColorCode.BrightMagenta: 15,
    TerminalColorCode.BrightCyan: 16,
    TerminalColorCode.BrightWhite: 17,
  };

  static Map<int, TerminalColorCode>? _reverseValueMap;

  static _ensureReverseValueMap() {
    if (_reverseValueMap != null) {
      return;
    }
    _reverseValueMap = Map<int, TerminalColorCode>();
    for (final entry in _enumValueMap.entries) {
      _reverseValueMap![entry.value] = entry.key;
    }
  }

  int get value => _enumValueMap[this]!;

  static TerminalColorCode? fromValue(int value) {
    _ensureReverseValueMap();
    return _reverseValueMap![value];
  }
}
