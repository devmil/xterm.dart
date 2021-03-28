class ControlCodes {
  static const NUL = 0x00;
  static const BEL = 0x07;
  static const BS = 0x08;
  static const HT = 0x09;
  static const LF = 0x0a;
  static const VT = 0x0b;
  static const FF = 0x0c;
  static const CR = 0x0d;
  static const SO = 0x0e;
  static const SI = 0x0f;
  static const CAN = 0x18;
  static const SUB = 0x1a;
  static const ESC = 0x1b;
  static const SP = 0x20;
  static const DEL = 0x7f;

  bool send8bit = false;

  ControlCodes([this.send8bit = false]);

  String get pad => send8bit ? '\u0080' : '\u001b@';
  String get hop => send8bit ? '\u0081' : '\u001bA';
  String get bph => send8bit ? '\u0082' : '\u001bB';
  String get nbh => send8bit ? '\u0083' : '\u001bC';
  String get ind => send8bit ? '\u0084' : '\u001bD';
  String get nel => send8bit ? '\u0085' : '\u001bE';
  String get ssa => send8bit ? '\u0086' : '\u001bF';
  String get esa => send8bit ? '\u0087' : '\u001bG';
  String get hts => send8bit ? '\u0088' : '\u001bH';
  String get htj => send8bit ? '\u0089' : '\u001bI';
  String get vts => send8bit ? '\u008a' : '\u001bJ';
  String get pld => send8bit ? '\u008b' : '\u001bK';
  String get plu => send8bit ? '\u008c' : '\u001bL';
  String get ri => send8bit ? '\u008d' : '\u001bM';
  String get ss2 => send8bit ? '\u008e' : '\u001bN';
  String get ss3 => send8bit ? '\u008f' : '\u001bO';
  String get dcs => send8bit ? '\u0090' : '\u001bP';
  String get pu1 => send8bit ? '\u0091' : '\u001bQ';
  String get pu2 => send8bit ? '\u0092' : '\u001bR';
  String get sts => send8bit ? '\u0093' : '\u001bS';
  String get cch => send8bit ? '\u0094' : '\u001bT';
  String get mw => send8bit ? '\u0095' : '\u001bU';
  String get spa => send8bit ? '\u0096' : '\u001bV';
  String get epa => send8bit ? '\u0097' : '\u001bW';
  String get sos => send8bit ? '\u0098' : '\u001bX';
  String get sgci => send8bit ? '\u0099' : '\u001bY';
  String get sci => send8bit ? '\u009a' : '\u001bZ';
  String get csi => send8bit ? '\u009b' : '\u001b[';
  String get st => send8bit ? '\u009c' : '\u001b\\';
  String get osc => send8bit ? '\u009d' : '\u001b]';
  String get pm => send8bit ? '\u009e' : '\u001b^';
  String get apc => send8bit ? '\u009f' : '\u001b_';
}
