import 'package:flutter/cupertino.dart';
import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/terminal/terminal.dart';

class BufferSet {
  Buffer _normal;
  Buffer _alt;
  late Buffer _active;

  BufferSet(Terminal terminal)
      : _normal = Buffer(terminal, hasScrollback: true),
        _alt = Buffer(terminal) {
    _normal.fillViewportRows();

    _active = _normal;
    setupTabStops();
  }

  bool get isAlternateBuffer => _active == _alt;

  Buffer get active => _active;

  activateNormalBuffer(bool clearAlt) {
    if (_active == _normal) {
      return;
    }

    _normal.x = _alt.x;
    _normal.y = _alt.y;

    if (clearAlt) {
      _alt.clear();
    }

    _active = _normal;
  }

  activateAltBuffer(int? fillAttr) {
    if (_active == _alt) {
      return;
    }
    _alt.x = _normal.x;
    _alt.y = _normal.y;

    _alt.fillViewportRows(fillAttr);
    _active = _alt;
  }

  resize(int newCols, int newRows) {
    _normal.resize(newCols, newRows);
    _alt.resize(newCols, newRows);
  }

  setupTabStops([int index = -1]) {
    _normal.setupTabStops(index);
    _alt.setupTabStops(index);
  }
}
