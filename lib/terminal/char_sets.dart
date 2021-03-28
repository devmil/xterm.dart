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
    _all = new Map<int, Map<int, String>>();

    _all![2] = {' '.runes.first: 'test', 'a'.runes.first: 'test2'};

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
    _all!['0'.runes.first] = {
      '`'.runes.first: '\u25c6', // '◆'
      'a'.runes.first: '\u2592', // '▒'
      'b'.runes.first: '\u2409', // [ht]
      'c'.runes.first: '\u240c', // [ff]
      'd'.runes.first: '\u240d', // [cr]
      'e'.runes.first: '\u240a', // [lf]
      'f'.runes.first: '\u00b0', // '°'
      'g'.runes.first: '\u00b1', // '±'
      'h'.runes.first: '\u2424', // [nl]
      'i'.runes.first: '\u240b', // [vt]
      'j'.runes.first: '\u2518', // '┘'
      'k'.runes.first: '\u2510', // '┐'
      'l'.runes.first: '\u250c', // '┌'
      'm'.runes.first: '\u2514', // '└'
      'n'.runes.first: '\u253c', // '┼'
      'o'.runes.first: '\u23ba', // '⎺'
      'p'.runes.first: '\u23bb', // '⎻'
      'q'.runes.first: '\u2500', // '─'
      'r'.runes.first: '\u23bc', // '⎼'
      's'.runes.first: '\u23bd', // '⎽'
      't'.runes.first: '\u251c', // '├'
      'u'.runes.first: '\u2524', // '┤'
      'v'.runes.first: '\u2534', // '┴'
      'w'.runes.first: '\u252c', // '┬'
      'x'.runes.first: '\u2502', // '│'
      'y'.runes.first: '\u2264', // '≤'
      'z'.runes.first: '\u2265', // '≥'
      '{'.runes.first: '\u03c0', // 'π'
      '|'.runes.first: '\u2260', // '≠'
      '}'.runes.first: '\u00a3', // '£'
      '~'.runes.first: '\u00b7' // '·'
    };

    // (DEC Alternate character ROM special graphics)
    _all!['2'.runes.first] = _all!['0'.runes.first]!;

    /**
     * British character set
     * ESC (A
     * Reference: http://vt100.net/docs/vt220-rm/table2-5.html
     */
    _all!['A'.runes.first] = {'#'.runes.first: '£'};

    /**
     * United States character set
     * ESC (B
     */
    _all!['B'.runes.first] = null;

    /**
     * Dutch character set
     * ESC (4
     * Reference: http://vt100.net/docs/vt220-rm/table2-6.html
     */
    _all!['4'.runes.first] = {
      '#'.runes.first: '£',
      '@'.runes.first: '¾',
      '['.runes.first: 'ij',
      '\\'.runes.first: '½',
      ']'.runes.first: '|',
      '{'.runes.first: '¨',
      '|'.runes.first: 'f',
      '}'.runes.first: '¼',
      '~'.runes.first: '´'
    };

    /**
     * Finnish character set
     * ESC (C or ESC (5
     * Reference: http://vt100.net/docs/vt220-rm/table2-7.html
     */
    _all!['C'.runes.first] = _all!['5'.runes.first] = {
      '['.runes.first: 'Ä',
      '\\'.runes.first: 'Ö',
      ']'.runes.first: 'Å',
      '^'.runes.first: 'Ü',
      '`'.runes.first: 'é',
      '{'.runes.first: 'ä',
      '|'.runes.first: 'ö',
      '}'.runes.first: 'å',
      '~'.runes.first: 'ü'
    };

    /**
     * French character set
     * ESC (R
     * Reference: http://vt100.net/docs/vt220-rm/table2-8.html
     */
    _all!['R'.runes.first] = {
      '#'.runes.first: '£',
      '@'.runes.first: 'à',
      '['.runes.first: '°',
      '\\'.runes.first: 'ç',
      ']'.runes.first: '§',
      '{'.runes.first: 'é',
      '|'.runes.first: 'ù',
      '}'.runes.first: 'è',
      '~'.runes.first: '¨'
    };

    /**
     * French Canadian character set
     * ESC (Q
     * Reference: http://vt100.net/docs/vt220-rm/table2-9.html
     */
    _all!['Q'.runes.first] = {
      '@'.runes.first: 'à',
      '['.runes.first: 'â',
      '\\'.runes.first: 'ç',
      ']'.runes.first: 'ê',
      '^'.runes.first: 'î',
      '`'.runes.first: 'ô',
      '{'.runes.first: 'é',
      '|'.runes.first: 'ù',
      '}'.runes.first: 'è',
      '~'.runes.first: 'û'
    };

    /**
     * German character set
     * ESC (K
     * Reference: http://vt100.net/docs/vt220-rm/table2-10.html
     */
    _all!['K'.runes.first] = {
      '@'.runes.first: '§',
      '['.runes.first: 'Ä',
      '\\'.runes.first: 'Ö',
      ']'.runes.first: 'Ü',
      '{'.runes.first: 'ä',
      '|'.runes.first: 'ö',
      '}'.runes.first: 'ü',
      '~'.runes.first: 'ß'
    };

    /**
     * Italian character set
     * ESC (Y
     * Reference: http://vt100.net/docs/vt220-rm/table2-11.html
     */
    _all!['Y'.runes.first] = {
      '#'.runes.first: '£',
      '@'.runes.first: '§',
      '['.runes.first: '°',
      '\\'.runes.first: 'ç',
      ']'.runes.first: 'é',
      '`'.runes.first: 'ù',
      '{'.runes.first: 'à',
      '|'.runes.first: 'ò',
      '}'.runes.first: 'è',
      '~'.runes.first: 'ì'
    };

    /**
     * Norwegian/Danish character set
     * ESC (E or ESC (6
     * Reference: http://vt100.net/docs/vt220-rm/table2-12.html
     */
    _all!['E'.runes.first] = _all!['6'.runes.first] = {
      '@'.runes.first: 'Ä',
      '['.runes.first: 'Æ',
      '\\'.runes.first: 'Ø',
      ']'.runes.first: 'Å',
      '^'.runes.first: 'Ü',
      '`'.runes.first: 'ä',
      '{'.runes.first: 'æ',
      '|'.runes.first: 'ø',
      '}'.runes.first: 'å',
      '~'.runes.first: 'ü'
    };

    /**
     * Spanish character set
     * ESC (Z
     * Reference: http://vt100.net/docs/vt220-rm/table2-13.html
     */

    _all!['Z'.runes.first] = {
      '#'.runes.first: '£',
      '@'.runes.first: '§',
      '['.runes.first: '¡',
      '\\'.runes.first: 'Ñ',
      ']'.runes.first: '¿',
      '{'.runes.first: '°',
      '|'.runes.first: 'ñ',
      '}'.runes.first: 'ç'
    };

    /**
     * Swedish character set
     * ESC (H or ESC (7
     * Reference: http://vt100.net/docs/vt220-rm/table2-14.html
     */
    _all!['H'.runes.first] = _all!['7'.runes.first] = {
      '@'.runes.first: 'É',
      '['.runes.first: 'Ä',
      '\\'.runes.first: 'Ö',
      ']'.runes.first: 'Å',
      '^'.runes.first: 'Ü',
      '`'.runes.first: 'é',
      '{'.runes.first: 'ä',
      '|'.runes.first: 'ö',
      '}'.runes.first: 'å',
      '~'.runes.first: 'ü'
    };

    /**
     * Swiss character set
     * ESC (=
     * Reference: http://vt100.net/docs/vt220-rm/table2-15.html
     */
    _all!['='.runes.first] = {
      '#'.runes.first: 'ù',
      '@'.runes.first: 'à',
      '['.runes.first: 'é',
      '\\'.runes.first: 'ç',
      ']'.runes.first: 'ê',
      '^'.runes.first: 'î',
      '_'.runes.first: 'è',
      '`'.runes.first: 'ô',
      '{'.runes.first: 'ä',
      '|'.runes.first: 'ö',
      '}'.runes.first: 'ü',
      '~'.runes.first: 'û'
    };
  }
}
