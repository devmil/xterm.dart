import 'dart:math';
import 'dart:typed_data';

import 'package:xterm/terminal/cursor.dart';

/// Cell layout:
///   | code point |  fg color  |  bg color  | attributes |
///       4bytes       4bytes       4bytes       4bytes
///
/// Attributes layout:
///   |  width  |  flags  | reserved | reserved |
///      1byte     1byte     1byte      1byte

const _cellSize = 16;

const _cellContent = 0;
const _cellFgColor = 4;
const _cellBgColor = 8;

// const _cellAttributes = 12;
const _cellWidth = 12;
const _cellFlags = 13;

class CellData {
  late ByteData _cellData;

  CellData() {
    _cellData = ByteData(_cellSize);
  }

  set content(int value) => _cellData.setInt32(_cellContent, value);

  int get content => _cellData.getInt32(_cellContent);

  set fgColor(int value) => _cellData.setInt32(_cellFgColor, value);

  int get fgColor => _cellData.getInt32(_cellFgColor);

  set bgColor(int value) => _cellData.setInt32(_cellBgColor, value);

  int get bgColor => _cellData.getInt32(_cellBgColor);

  set width(int value) => _cellData.setInt8(_cellWidth, value);

  int get width => _cellData.getInt8(_cellWidth);

  set flags(int value) => _cellData.setInt8(_cellFlags, value);

  int get flags => _cellData.getInt8(_cellFlags);

  bool get hasContent => content != 0;

  void clearFlags() {
    flags = 0;
  }

  bool hasFlag(int flag) {
    return flags & flag != 0;
  }

  void cellSetFlag(int flag) {
    flags = flags | flag;
  }

  void clear() {
    content = 0;
    fgColor = 0;
    bgColor = 0;
    width = 0;
    flags = 0;
  }

  void erase(Cursor cursor) {
    content = 0;
    fgColor = cursor.fg;
    bgColor = cursor.bg;
    flags = cursor.flags;
    width = 0;
  }

  void initialize({
    required int content,
    required int width,
    required Cursor cursor,
  }) {
    this.content = content;
    this.fgColor = cursor.fg;
    this.bgColor = cursor.bg;
    this.width = width;
    this.flags = cursor.flags;
  }
}

class BufferLine {
  BufferLine({this.isWrapped = false}) {
    _cells = List<CellData>.generate(64, (index) => CellData(), growable: true);
  }

  late List<CellData> _cells;

  bool isWrapped;

  void ensure(int length) {
    if (_cells.length >= length) {
      return;
    }

    final diff = length - _cells.length;

    _cells.addAll(List<CellData>.generate(diff, (index) => CellData()));
  }

  void insert(int index) {
    insertN(index, 1);
  }

  void removeN(int index, int count) {
    _cells.removeRange(index, index + count);
  }

  void insertN(int index, int count) {
    _cells.insertAll(
        index, List<CellData>.generate(count, (index) => CellData()));
  }

  void clear() {
    _cells.forEach((cell) => cell.clear());
  }

  void erase(Cursor cursor, int start, int end, [bool resetIsWrapped = false]) {
    ensure(end);
    for (var i = start; i < end; i++) {
      _cells[i].erase(cursor);
    }
    if (resetIsWrapped) {
      isWrapped = false;
    }
  }

  CellData operator [](int index) {
    ensure(index + 1);
    return _cells[index];
  }

  int getTrimmedLength([int? cols]) {
    if (cols == null) {
      cols = _cells.length;
    }
    for (int i = cols - 1; i >= 0; i--) {
      if (_cells[i].content != 0) {
        return _cells.fold(0, (curLen, cell) => curLen + cell.width);
      }
    }
    return 0;
  }

  void moveCellsFrom(BufferLine src, int srcCol, int dstCol, int len) {
    final srcList = src._cells.sublist(srcCol, srcCol + len);
    _cells.insertAll(dstCol, srcList);
    src._cells.removeRange(srcCol, srcCol + len);
  }

  // int cellGetHash(int index) {
  //   final cell = index * _cellSize;
  //   final a = _cells.getInt64(cell);
  //   final b = _cells.getInt64(cell + 8);
  //   return a ^ b;
  // }

  void clearRange(int start, int end) {
    end = min(end, _cells.length);
    for (var index = start; index < end; index++) {
      _cells[index].content = 0;
    }
  }

  @override
  String toString() {
    final result = StringBuffer();
    for (int i = 0; i < _cells.length; i++) {
      final code = _cells[i].content;
      if (code == 0) {
        continue;
      }
      result.writeCharCode(code);
    }
    return result.toString();
  }

  String toDebugString(int cols) {
    final result = StringBuffer();
    final length = getTrimmedLength();
    for (int i = 0; i < max(cols, length); i++) {
      var code = _cells[i].content;
      if (code == 0) {
        if (_cells[i].width == 0) {
          code = '_'.runes.first;
        } else {
          code = _cells[i].width.toString().runes.first;
        }
      }
      result.writeCharCode(code);
    }
    return result.toString();
  }
}
