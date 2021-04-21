import 'dart:math';
import 'dart:typed_data';

import 'package:xterm/terminal/cursor.dart';

/// Line layout:
///   |  cell  |  cell  |  cell  |  cell  | ...
///   (16 bytes per cell)
///
/// Cell layout:
///   | code point |  fg color  |  bg color  | attributes |
///       4bytes       4bytes       4bytes       4bytes
///
/// Attributes layout:
///   |  width  |  flags  | reserved | reserved |
///      1byte     1byte     1byte      1byte

int _nextLength(int lengthRequirement) {
  var nextLength = 2;
  while (nextLength < lengthRequirement) {
    nextLength *= 2;
  }
  return nextLength;
}

abstract class ReadOnlyBufferLine {
  static const cellSize = 16;
  static const cellSize64Bit = cellSize >> 3;

  static const cellContent = 0;
  static const cellFgColor = 4;
  static const cellBgColor = 8;

// const _cellAttributes = 12;
  static const cellWidth = 12;
  static const cellFlags = 13;

  bool get isWrapped;

  bool cellHasContent(int index);
  int cellGetContent(int index);
  int cellGetFgColor(int index);
  int cellGetBgColor(int index);
  int cellGetFlags(int index);
  int cellGetWidth(int index);
  bool cellHasFlag(int index, int flag);
  int getTrimmedLength([int? cols]);
}

class BufferLine implements ReadOnlyBufferLine {
  BufferLine({int length = 64, this.isWrapped = false}) {
    _maxCols = _nextLength(length);
    _cells = ByteData(_maxCols * ReadOnlyBufferLine.cellSize);
  }

  late ByteData _cells;

  ByteData getCells() {
    return _cells;
  }

  @override
  bool isWrapped;

  int _maxCols = 64;

  void ensure(int length) {
    if (length <= _maxCols) {
      return;
    }

    final nextLength = _nextLength(length);
    final newCells = ByteData(nextLength * ReadOnlyBufferLine.cellSize);
    newCells.buffer.asInt64List().setAll(0, _cells.buffer.asInt64List());
    _cells = newCells;
    _maxCols = nextLength;
  }

  void insert(int index) {
    insertN(index, 1);
  }

  void removeN(int index, int count) {
    final moveStart = index * ReadOnlyBufferLine.cellSize64Bit;
    final moveOffset = count * ReadOnlyBufferLine.cellSize64Bit;
    final moveEnd = (_maxCols - count) * ReadOnlyBufferLine.cellSize64Bit;
    final bufferEnd = _maxCols * ReadOnlyBufferLine.cellSize64Bit;

    // move data backward
    final cells = _cells.buffer.asInt64List();
    for (var i = moveStart; i < moveEnd; i++) {
      cells[i] = cells[i + moveOffset];
    }

    // set empty cells to 0
    for (var i = moveEnd; i < bufferEnd; i++) {
      cells[i] = 0x00;
    }
  }

  void insertN(int index, int count) {
    //                       start
    // +--------------------------|-----------------------------------+
    // |                          |                                   |
    // +--------------------------\--\--------------------------------+ end
    //                             \  \
    //                              \  \
    //                               v  v
    // +--------------------------|--|--------------------------------+
    // |                          |  |                                |
    // +--------------------------|--|--------------------------------+ end
    //                       start   start+offset

    final moveStart = index * ReadOnlyBufferLine.cellSize64Bit;
    final moveOffset = count * ReadOnlyBufferLine.cellSize64Bit;
    final bufferEnd = _maxCols * ReadOnlyBufferLine.cellSize64Bit;

    // move data forward
    final cells = _cells.buffer.asInt64List();
    for (var i = bufferEnd - moveOffset - 1; i >= moveStart; i--) {
      cells[i + moveOffset] = cells[i];
    }

    // set inserted cells to 0
    for (var i = moveStart; i < moveStart + moveOffset; i++) {
      cells[i] = 0x00;
    }
  }

  void clear() {
    clearRange(0, _cells.lengthInBytes ~/ ReadOnlyBufferLine.cellSize);
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

  void cellClear(int index) {
    _cells.setInt64(index * ReadOnlyBufferLine.cellSize, 0x00);
    _cells.setInt64(index * ReadOnlyBufferLine.cellSize + 8, 0x00);
  }

  void cellInitialize(
    int index, {
    required int content,
    required int width,
    required Cursor cursor,
  }) {
    final cell = index * ReadOnlyBufferLine.cellSize;
    _cells.setInt32(cell + ReadOnlyBufferLine.cellContent, content);
    _cells.setInt32(cell + ReadOnlyBufferLine.cellFgColor, cursor.fg);
    _cells.setInt32(cell + ReadOnlyBufferLine.cellBgColor, cursor.bg);
    _cells.setInt8(cell + ReadOnlyBufferLine.cellWidth, width);
    _cells.setInt8(cell + ReadOnlyBufferLine.cellFlags, cursor.flags);
  }

  @override
  bool cellHasContent(int index) {
    return cellGetContent(index) != 0;
  }

  @override
  int cellGetContent(int index) {
    return _cells.getUint32(
        index * ReadOnlyBufferLine.cellSize + ReadOnlyBufferLine.cellContent);
  }

  void cellSetContent(int index, int content) {
    _cells.setInt32(
        index * ReadOnlyBufferLine.cellSize + ReadOnlyBufferLine.cellContent,
        content);
  }

  @override
  int cellGetFgColor(int index) {
    if (index >= _maxCols) {
      return 0;
    }
    return _cells.getInt32(
        index * ReadOnlyBufferLine.cellSize + ReadOnlyBufferLine.cellFgColor);
  }

  void cellSetFgColor(int index, int color) {
    _cells.setInt32(
        index * ReadOnlyBufferLine.cellSize + ReadOnlyBufferLine.cellFgColor,
        color);
  }

  @override
  int cellGetBgColor(int index) {
    if (index >= _maxCols) {
      return 0;
    }
    return _cells.getInt32(
        index * ReadOnlyBufferLine.cellSize + ReadOnlyBufferLine.cellBgColor);
  }

  void cellSetBgColor(int index, int color) {
    _cells.setInt32(
        index * ReadOnlyBufferLine.cellSize + ReadOnlyBufferLine.cellBgColor,
        color);
  }

  @override
  int cellGetFlags(int index) {
    if (index >= _maxCols) {
      return 0;
    }
    return _cells.getInt8(
        index * ReadOnlyBufferLine.cellSize + ReadOnlyBufferLine.cellFlags);
  }

  void cellSetFlags(int index, int flags) {
    _cells.setInt8(
        index * ReadOnlyBufferLine.cellSize + ReadOnlyBufferLine.cellFlags,
        flags);
  }

  @override
  int cellGetWidth(int index) {
    if (index >= _maxCols) {
      return 1;
    }
    return _cells.getInt8(
        index * ReadOnlyBufferLine.cellSize + ReadOnlyBufferLine.cellWidth);
  }

  void cellSetWidth(int index, int width) {
    _cells.setInt8(
        index * ReadOnlyBufferLine.cellSize + ReadOnlyBufferLine.cellWidth,
        width);
  }

  void cellClearFlags(int index) {
    cellSetFlags(index, 0);
  }

  @override
  bool cellHasFlag(int index, int flag) {
    if (index >= _maxCols) {
      return false;
    }
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

  @override
  int getTrimmedLength([int? cols]) {
    if (cols == null) {
      cols = _maxCols;
    }
    for (var i = cols - 1; i >= 0; i--) {
      if (cellGetContent(i) != 0) {
        // we are at the last cell in this line that has content.
        // the length of this line is the index of this cell + 1
        // the only exception is that if that last cell is wider
        // than 1 then we have to add the diff
        final lastCellWidth = cellGetWidth(i);
        return i + lastCellWidth;
      }
    }
    return 0;
  }

  void copyCellsFrom(BufferLine src, int srcCol, int dstCol, int len) {
    ensure(dstCol + len);

    final intsToCopy = len * ReadOnlyBufferLine.cellSize64Bit;
    final srcStart = srcCol * ReadOnlyBufferLine.cellSize64Bit;
    final dstStart = dstCol * ReadOnlyBufferLine.cellSize64Bit;

    final cells = _cells.buffer.asInt64List();
    final srcCells = src._cells.buffer.asInt64List();
    for (var i = 0; i < intsToCopy; i++) {
      cells[dstStart + i] = srcCells[srcStart + i];
    }
  }

  // int cellGetHash(int index) {
  //   final cell = index * _cellSize;
  //   final a = _cells.getInt64(cell);
  //   final b = _cells.getInt64(cell + 8);
  //   return a ^ b;
  // }

  void removeRange(int start, int end) {
    end = min(end, _maxCols);
    this.removeN(start, end - start);
  }

  void clearRange(int start, int end) {
    end = min(end, _maxCols);
    for (var index = start; index < end; index++) {
      cellClear(index);
    }
  }

  @override
  String toString() {
    final result = StringBuffer();
    for (int i = 0; i < _maxCols; i++) {
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
