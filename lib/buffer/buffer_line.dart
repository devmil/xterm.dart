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

class _CellData {
  late ByteData _cellData;

  _CellData() {
    _cellData = ByteData(_cellSize);
  }

  set content(int value) {
    _cellData.setInt32(_cellContent, value);
  }

  int get content {
    return _cellData.getInt32(_cellContent);
  }

  set fgColor(int value) {
    _cellData.setInt32(_cellFgColor, value);
  }

  int get fgColor {
    return _cellData.getInt32(_cellFgColor);
  }

  set bgColor(int value) {
    _cellData.setInt32(_cellBgColor, value);
  }

  int get bgColor {
    return _cellData.getInt32(_cellBgColor);
  }

  set width(int value) {
    _cellData.setInt8(_cellWidth, value);
  }

  int get width {
    return _cellData.getInt8(_cellWidth);
  }

  set flags(int value) {
    _cellData.setInt8(_cellFlags, value);
  }

  int get flags {
    return _cellData.getInt8(_cellFlags);
  }

  void clear() {
    content = 0;
    fgColor = 0;
    bgColor = 0;
    width = 0;
    flags = 0;
  }

  void copyFrom(_CellData cell) {
    _cellData.buffer.asInt8List().setAll(0, cell._cellData.buffer.asInt8List());
  }
}

class BufferLine {
  BufferLine({this.isWrapped = false}) {
    _cells =
        List<_CellData>.generate(64, (index) => _CellData(), growable: true);
  }

  late List<_CellData> _cells;

  bool isWrapped;

  void ensure(int length) {
    if (_cells.length >= length) {
      return;
    }

    final diff = length - _cells.length;

    _cells.addAll(List<_CellData>.generate(diff, (index) => _CellData()));
  }

  void insert(int index) {
    insertN(index, 1);
  }

  void removeN(int index, int count) {
    _cells.removeRange(index, index + count);
  }

  void insertN(int index, int count) {
    _cells.insertAll(
        index, List<_CellData>.generate(count, (index) => _CellData()));
  }

  void clear() {
    _cells.forEach((cell) => cell.clear());
  }

  void erase(Cursor cursor, int start, int end, [bool resetIsWrapped = false]) {
    ensure(end);
    for (var i = start; i < end; i++) {
      cellErase(i, cursor);
    }
    if (resetIsWrapped) {
      isWrapped = false;
    }
  }

  void cellInitialize(
    int index, {
    required int content,
    required int width,
    required Cursor cursor,
  }) {
    final cell = _cells[index];
    cell.content = content;
    cell.fgColor = cursor.fg;
    cell.bgColor = cursor.bg;
    cell.width = width;
    cell.flags = cursor.flags;
  }

  bool cellHasContent(int index) {
    return cellGetContent(index) != 0;
  }

  int cellGetContent(int index) {
    if (index >= _cells.length) {
      return 0;
    }
    return _cells[index].content;
  }

  void cellSetContent(int index, int content) {
    _cells[index].content = content;
  }

  int cellGetFgColor(int index) {
    if (index >= _cells.length) {
      return 0;
    }
    return _cells[index].fgColor;
  }

  void cellSetFgColor(int index, int color) {
    _cells[index].fgColor = color;
  }

  int cellGetBgColor(int index) {
    if (index >= _cells.length) {
      return 0;
    }
    return _cells[index].bgColor;
  }

  void cellSetBgColor(int index, int color) {
    _cells[index].bgColor = color;
  }

  int cellGetFlags(int index) {
    if (index >= _cells.length) {
      return 0;
    }
    return _cells[index].flags;
  }

  void cellSetFlags(int index, int flags) {
    _cells[index].flags = flags;
  }

  int cellGetWidth(int index) {
    if (index >= _cells.length) {
      return 0;
    }
    return _cells[index].width;
  }

  void cellSetWidth(int index, int width) {
    _cells[index].width = width;
  }

  void cellClearFlags(int index) {
    cellSetFlags(index, 0);
  }

  bool cellHasFlag(int index, int flag) {
    return cellGetFlags(index) & flag != 0;
  }

  void cellSetFlag(int index, int flag) {
    cellSetFlags(index, cellGetFlags(index) | flag);
  }

  void cellErase(int index, Cursor cursor) {
    cellSetContent(index, 0x00);
    cellSetFgColor(index, cursor.fg);
    cellSetBgColor(index, cursor.bg);
    cellSetFlags(index, cursor.flags);
    cellSetWidth(index, 0);
  }

  int getTrimmedLength([int? cols]) {
    if (cols == null) {
      cols = _cells.length;
    }
    for (int i = cols; i >= 0; i--) {
      if (cellGetContent(i) != 0) {
        int length = 0;
        for (int j = 0; j <= i; j++) {
          length += cellGetWidth(j);
        }
        return length;
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
      cellSetContent(index, 0x00);
    }
  }

  @override
  String toString() {
    final result = StringBuffer();
    for (int i = 0; i < _cells.length; i++) {
      final code = cellGetContent(i);
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
      var code = cellGetContent(i);
      if (code == 0) {
        if (cellGetWidth(i) == 0) {
          code = '_'.runes.first;
        } else {
          code = cellGetWidth(i).toString().runes.first;
        }
      }
      result.writeCharCode(code);
    }
    return result.toString();
  }
}
