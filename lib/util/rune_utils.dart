import 'dart:typed_data';

class RuneUtils {
  static int expectedSizeFromFirstByte(int byte) {
    var x = first[byte];

    // Invalid runes, just return 1 for byte, and let higher level pass to print
    if (x == xx) return -1;
    if (x == a1) return 1;
    return x & 0xf;
  }

  static const int xx = 0xF1; // invalid: size 1
  static const int a1 = 0xF0; // a1CII: size 1
  static const int s1 = 0x02; // accept 0, size 2
  static const int s2 = 0x13; // accept 1, size 3
  static const int s3 = 0x03; // accept 0, size 3
  static const int s4 = 0x23; // accept 2, size 3
  static const int s5 = 0x34; // accept 3, size 4
  static const int s6 = 0x04; // accept 0, size 4
  static const int s7 = 0x44; // accept 4, size 4

  static final first = [
    //   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, // 0x00-0x0F
    a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, // 0x10-0x1F
    a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, // 0x20-0x2F
    a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, // 0x30-0x3F
    a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, // 0x40-0x4F
    a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, // 0x50-0x5F
    a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, // 0x60-0x6F
    a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, a1, // 0x70-0x7F

    //   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, // 0x80-0x8F
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, // 0x90-0x9F
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, // 0xA0-0xAF
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, // 0xB0-0xBF
    xx, xx, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, // 0xC0-0xCF
    s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, // 0xD0-0xDF
    s2, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s4, s3, s3, // 0xE0-0xEF
    s5, s6, s6, s6, s7, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, // 0xF0-0xFF
  ];

  // The default lowest and highest continuation byte.
  static const int locb = 0x80; // 1000 0000
  static const int hicb = 0xBF; // 1011 1111

  static final _acceptRanges = [
    _AcceptRange(locb, hicb),
    _AcceptRange(0xa0, hicb),
    _AcceptRange(locb, 0x9f),
    _AcceptRange(0x90, hicb),
    _AcceptRange(locb, 0x8f),
  ];

  static bool fullRune(Uint8List? p, int n) {
    if (p == null) throw ArgumentError.value(p, 'p');

    if (n == 0) {
      return false;
    }
    var x = first[p[0]];
    if (n >= (x & 7)) {
      // ascii, invalid or valid
      return true;
    }
    // must be short or invalid
    if (n > 1) {
      var accept = _acceptRanges[x >> 4];
      var c = p[1];
      if (c < accept.lo || accept.hi < c)
        return true;
      else if (n > 2 && (p[2] < locb || hicb < p[2])) return true;
    }
    return false;
  }
}

class _AcceptRange {
  int lo, hi;
  _AcceptRange(this.lo, this.hi);
}
