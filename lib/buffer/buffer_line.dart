import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:xterm/buffer/char_data.dart';

class BufferLine {
  List<CharData> _data = List<CharData>.empty(growable: true);
  bool isWrapped = false;

  int get length => _data.length;

  BufferLine(int cols, CharData fillCharData, {this.isWrapped = false}) {
    _data =
        List<CharData>.generate(cols, (_) => CharData.createFrom(fillCharData));
  }

  BufferLine._(this._data, this.isWrapped);

  static BufferLine copyFrom(BufferLine other) {
    return BufferLine._(
        List<CharData>.generate(other._data.length,
            (index) => CharData.createFrom(other._data[index])),
        other.isWrapped);
  }

  CharData operator [](int index) {
    return _data[index];
  }

  operator []=(int index, CharData charData) {
    _data[index].copyFrom(charData);
  }

  int widthAt(int index) {
    return _data[index].width;
  }

  bool hasContent(int index) => _data[index].hasContent;

  bool get hasAnyContent => _data.any((element) => element.hasContent);

  void insertCells(int pos, int n, int rightMargin, CharData fillCharData) {
    final len = min(rightMargin + 1, length);
    pos = pos % len;
    if (n < len - pos) {
      for (var i = len - pos - n - 1; i >= 0; --i) {
        _data[pos + n + i] = _data[pos + i];
      }
      for (var i = 0; i < n; i++) {
        _data[pos + i].copyFrom(fillCharData);
      }
    } else {
      for (var i = pos; i < len; ++i) {
        _data[i].copyFrom(fillCharData);
      }
    }
  }

  void deleteCells(int pos, int n, int rightMargin, CharData fillCharData) {
    final len = min(rightMargin + 1, length);
    pos %= len;
    if (n < len - pos) {
      for (var i = 0; i < len - pos - n; ++i) {
        _data[pos + i] = this[pos + n + i];
      }
      for (var i = len - n; i < len; ++i) {
        _data[i].copyFrom(fillCharData);
      }
    } else {
      for (var i = pos; i < len; ++i) {
        _data[i].copyFrom(fillCharData);
      }
    }
  }

  void replaceCells(int start, int end, CharData fillCharData) {
    final len = length;

    while (start < end && start < len) {
      _data[start++].copyFrom(fillCharData);
    }
  }

  void resize(int cols, CharData fillCharData) {
    final len = length;

    if (cols == len) {
      return;
    }

    final newData = List<CharData>.generate(
        cols,
        (index) =>
            index < len ? _data[index] : CharData.createFrom(fillCharData));
    _data = newData;
  }

  void fill(CharData fillCharData) {
    _data.forEach((element) {
      element.copyFrom(fillCharData);
    });
  }

  void fillRange(CharData fillCharData, int start, int len) {
    _data.skip(start).take(len).forEach((element) {
      element.copyFrom(fillCharData);
    });
  }

  void copyFrom(BufferLine line) {
    final newLength = max(_data.length, line._data.length);
    _data = List<CharData>.generate(newLength, (index) {
      //we are beyond the cell that the source line can deliver => just reuse what we had there
      if (index >= line._data.length) {
        return _data[index];
      }
      if (index < _data.length) {
        //for this index we already have a CharData instance => reuse it
        final cell = _data[index];
        cell.copyFrom(line._data[index]);
        return cell;
      } else {
        //we have to create a new cell
        return CharData.createFrom(line._data[index]);
      }
    });
    isWrapped = line.isWrapped;
  }

  void copyFromRange(BufferLine source, int sourceCol, int destCol, int len) {
    for (int i = 0; i < len; i++) {
      final sourceIdx = sourceCol + i;
      final destIdx = destCol + i;
      if (destIdx < _data.length && sourceIdx < source._data.length) {
        _data[destIdx].copyFrom(source._data[sourceIdx]);
      }
    }
  }

  int get trimmedLength {
    for (int i = _data.length - 1; i >= 0; --i) {
      if (_data[i].code != 0) {
        var width = 0;
        for (int j = 0; i <= i; j++) {
          width += _data[i].width;
        }
        return width;
      }
    }
    return 0;
  }

  String translateToString(
      {bool trimRight = false, int startCol = 0, int endCol = -1}) {
    if (endCol == -1) {
      endCol = _data.length;
    }
    if (trimRight) {
      // make sure endCol is not before startCol if we set it to the trimmed length
      endCol = max(min(endCol, trimmedLength), startCol);
    }

    final sb = StringBuffer();
    _data.forEach((element) {
      if (element.code != 0) {
        sb.write(element.rune);
      }
    });

    return sb.toString();
  }
}
