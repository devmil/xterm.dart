import 'dart:typed_data';

class BitArray {
  int _length;
  Uint8List _data;

  BitArray(this._length) : _data = Uint8List((_length / 8).ceil());

  int get length => _length;

  set length(int value) {
    _length = value;
    _data = Uint8List((_length / 8).ceil());
  }

  bool operator [](int index) {
    final byteIndex = (index / 8).floor();
    final bitOffset = index % 8;
    final mask = 0x01 << bitOffset;
    return (_data[byteIndex] & mask) != 0;
  }

  operator []=(int index, bool value) {
    if (index >= _length) {
      throw ArgumentError.value(
          index, 'index', 'Index out of bounds. BitArray length is $_length');
    }
    final byteIndex = (index / 8).floor();
    final bitOffset = index % 8;
    if (value) {
      var mask = 0x01 << bitOffset;
      _data[byteIndex] |= mask;
    } else {
      var mask = ~(0x01 << bitOffset);
      _data[byteIndex] &= mask;
    }
  }
}
