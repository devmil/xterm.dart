class CharSets {
  static Map<int, Map<int, String>?>? _all;
  static Map<int, String>? Default;

  static Map<int, Map<int, String>?> get all {
    _ensureInitialized();
    return _all!;
  }

  static _ensureInitialized() {
    if (_all == null) {
      _initialize();
    }
  }

  static _initialize() {
    _all = new Map<int, Map<int, String>?>();

    _all![2] = {' '.codeUnitAt(0): 'test', 'a'.codeUnitAt(0): 'test2'};

    //
    // DEC Special Character and Line Drawing Set.
    // Reference: http://vt100.net/docs/vt102-ug/table5-13.html
    // A lot of curses apps use this if they see TERM=xterm.
    // testing: echo -e '\e(0a\e(B'
    // The xterm output sometimes seems to conflict with the
    // reference above. xterm seems in line with the reference
    // when running vttest however.
    // The table below now uses xterm's output from vttest.
    //
    _all!['0'.codeUnitAt(0)] = {
      '`'.codeUnitAt(0): '\u25c6', // '◆'
      'a'.codeUnitAt(0): '\u2592', // '▒'
      'b'.codeUnitAt(0): '\u2409', // [ht]
      'c'.codeUnitAt(0): '\u240c', // [ff]
      'd'.codeUnitAt(0): '\u240d', // [cr]
      'e'.codeUnitAt(0): '\u240a', // [lf]
      'f'.codeUnitAt(0): '\u00b0', // '°'
      'g'.codeUnitAt(0): '\u00b1', // '±'
      'h'.codeUnitAt(0): '\u2424', // [nl]
      'i'.codeUnitAt(0): '\u240b', // [vt]
      'j'.codeUnitAt(0): '\u2518', // '┘'
      'k'.codeUnitAt(0): '\u2510', // '┐'
      'l'.codeUnitAt(0): '\u250c', // '┌'
      'm'.codeUnitAt(0): '\u2514', // '└'
      'n'.codeUnitAt(0): '\u253c', // '┼'
      'o'.codeUnitAt(0): '\u23ba', // '⎺'
      'p'.codeUnitAt(0): '\u23bb', // '⎻'
      'q'.codeUnitAt(0): '\u2500', // '─'
      'r'.codeUnitAt(0): '\u23bc', // '⎼'
      's'.codeUnitAt(0): '\u23bd', // '⎽'
      't'.codeUnitAt(0): '\u251c', // '├'
      'u'.codeUnitAt(0): '\u2524', // '┤'
      'v'.codeUnitAt(0): '\u2534', // '┴'
      'w'.codeUnitAt(0): '\u252c', // '┬'
      'x'.codeUnitAt(0): '\u2502', // '│'
      'y'.codeUnitAt(0): '\u2264', // '≤'
      'z'.codeUnitAt(0): '\u2265', // '≥'
      '{'.codeUnitAt(0): '\u03c0', // 'π'
      '|'.codeUnitAt(0): '\u2260', // '≠'
      '}'.codeUnitAt(0): '\u00a3', // '£'
      '~'.codeUnitAt(0): '\u00b7' // '·'
    };

    // (DEC Alternate character ROM special graphics)
    _all!['2'.codeUnitAt(0)] = _all!['0'.codeUnitAt(0)]!;

    /**
     * British character set
     * ESC (A
     * Reference: http://vt100.net/docs/vt220-rm/table2-5.html
     */
    _all!['A'.codeUnitAt(0)] = {'#'.codeUnitAt(0): '£'};

    /**
     * United States character set
     * ESC (B
     */
    _all!['B'.codeUnitAt(0)] = null;

    /**
     * Dutch character set
     * ESC (4
     * Reference: http://vt100.net/docs/vt220-rm/table2-6.html
     */
    _all!['4'.codeUnitAt(0)] = {
      '#'.codeUnitAt(0): '£',
      '@'.codeUnitAt(0): '¾',
      '['.codeUnitAt(0): 'ij',
      '\\'.codeUnitAt(0): '½',
      ']'.codeUnitAt(0): '|',
      '{'.codeUnitAt(0): '¨',
      '|'.codeUnitAt(0): 'f',
      '}'.codeUnitAt(0): '¼',
      '~'.codeUnitAt(0): '´'
    };

    /**
     * Finnish character set
     * ESC (C or ESC (5
     * Reference: http://vt100.net/docs/vt220-rm/table2-7.html
     */
    _all!['C'.codeUnitAt(0)] = _all!['5'.codeUnitAt(0)] = {
      '['.codeUnitAt(0): 'Ä',
      '\\'.codeUnitAt(0): 'Ö',
      ']'.codeUnitAt(0): 'Å',
      '^'.codeUnitAt(0): 'Ü',
      '`'.codeUnitAt(0): 'é',
      '{'.codeUnitAt(0): 'ä',
      '|'.codeUnitAt(0): 'ö',
      '}'.codeUnitAt(0): 'å',
      '~'.codeUnitAt(0): 'ü'
    };

    /**
     * French character set
     * ESC (R
     * Reference: http://vt100.net/docs/vt220-rm/table2-8.html
     */
    _all!['R'.codeUnitAt(0)] = {
      '#'.codeUnitAt(0): '£',
      '@'.codeUnitAt(0): 'à',
      '['.codeUnitAt(0): '°',
      '\\'.codeUnitAt(0): 'ç',
      ']'.codeUnitAt(0): '§',
      '{'.codeUnitAt(0): 'é',
      '|'.codeUnitAt(0): 'ù',
      '}'.codeUnitAt(0): 'è',
      '~'.codeUnitAt(0): '¨'
    };

    /**
     * French Canadian character set
     * ESC (Q
     * Reference: http://vt100.net/docs/vt220-rm/table2-9.html
     */
    _all!['Q'.codeUnitAt(0)] = {
      '@'.codeUnitAt(0): 'à',
      '['.codeUnitAt(0): 'â',
      '\\'.codeUnitAt(0): 'ç',
      ']'.codeUnitAt(0): 'ê',
      '^'.codeUnitAt(0): 'î',
      '`'.codeUnitAt(0): 'ô',
      '{'.codeUnitAt(0): 'é',
      '|'.codeUnitAt(0): 'ù',
      '}'.codeUnitAt(0): 'è',
      '~'.codeUnitAt(0): 'û'
    };

    /**
     * German character set
     * ESC (K
     * Reference: http://vt100.net/docs/vt220-rm/table2-10.html
     */
    _all!['K'.codeUnitAt(0)] = {
      '@'.codeUnitAt(0): '§',
      '['.codeUnitAt(0): 'Ä',
      '\\'.codeUnitAt(0): 'Ö',
      ']'.codeUnitAt(0): 'Ü',
      '{'.codeUnitAt(0): 'ä',
      '|'.codeUnitAt(0): 'ö',
      '}'.codeUnitAt(0): 'ü',
      '~'.codeUnitAt(0): 'ß'
    };

    /**
     * Italian character set
     * ESC (Y
     * Reference: http://vt100.net/docs/vt220-rm/table2-11.html
     */
    _all!['Y'.codeUnitAt(0)] = {
      '#'.codeUnitAt(0): '£',
      '@'.codeUnitAt(0): '§',
      '['.codeUnitAt(0): '°',
      '\\'.codeUnitAt(0): 'ç',
      ']'.codeUnitAt(0): 'é',
      '`'.codeUnitAt(0): 'ù',
      '{'.codeUnitAt(0): 'à',
      '|'.codeUnitAt(0): 'ò',
      '}'.codeUnitAt(0): 'è',
      '~'.codeUnitAt(0): 'ì'
    };

    /**
     * Norwegian/Danish character set
     * ESC (E or ESC (6
     * Reference: http://vt100.net/docs/vt220-rm/table2-12.html
     */
    _all!['E'.codeUnitAt(0)] = _all!['6'.codeUnitAt(0)] = {
      '@'.codeUnitAt(0): 'Ä',
      '['.codeUnitAt(0): 'Æ',
      '\\'.codeUnitAt(0): 'Ø',
      ']'.codeUnitAt(0): 'Å',
      '^'.codeUnitAt(0): 'Ü',
      '`'.codeUnitAt(0): 'ä',
      '{'.codeUnitAt(0): 'æ',
      '|'.codeUnitAt(0): 'ø',
      '}'.codeUnitAt(0): 'å',
      '~'.codeUnitAt(0): 'ü'
    };

    /**
     * Spanish character set
     * ESC (Z
     * Reference: http://vt100.net/docs/vt220-rm/table2-13.html
     */

    _all!['Z'.codeUnitAt(0)] = {
      '#'.codeUnitAt(0): '£',
      '@'.codeUnitAt(0): '§',
      '['.codeUnitAt(0): '¡',
      '\\'.codeUnitAt(0): 'Ñ',
      ']'.codeUnitAt(0): '¿',
      '{'.codeUnitAt(0): '°',
      '|'.codeUnitAt(0): 'ñ',
      '}'.codeUnitAt(0): 'ç'
    };

    /**
     * Swedish character set
     * ESC (H or ESC (7
     * Reference: http://vt100.net/docs/vt220-rm/table2-14.html
     */
    _all!['H'.codeUnitAt(0)] = _all!['7'.codeUnitAt(0)] = {
      '@'.codeUnitAt(0): 'É',
      '['.codeUnitAt(0): 'Ä',
      '\\'.codeUnitAt(0): 'Ö',
      ']'.codeUnitAt(0): 'Å',
      '^'.codeUnitAt(0): 'Ü',
      '`'.codeUnitAt(0): 'é',
      '{'.codeUnitAt(0): 'ä',
      '|'.codeUnitAt(0): 'ö',
      '}'.codeUnitAt(0): 'å',
      '~'.codeUnitAt(0): 'ü'
    };

    /**
     * Swiss character set
     * ESC (=
     * Reference: http://vt100.net/docs/vt220-rm/table2-15.html
     */
    _all!['='.codeUnitAt(0)] = {
      '#'.codeUnitAt(0): 'ù',
      '@'.codeUnitAt(0): 'à',
      '['.codeUnitAt(0): 'é',
      '\\'.codeUnitAt(0): 'ç',
      ']'.codeUnitAt(0): 'ê',
      '^'.codeUnitAt(0): 'î',
      '_'.codeUnitAt(0): 'è',
      '`'.codeUnitAt(0): 'ô',
      '{'.codeUnitAt(0): 'ä',
      '|'.codeUnitAt(0): 'ö',
      '}'.codeUnitAt(0): 'ü',
      '~'.codeUnitAt(0): 'û'
    };
  }
}
