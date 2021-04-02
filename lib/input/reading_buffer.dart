import 'dart:typed_data';

class ReadingBuffer {
  Uint8List _putbackBuffer = Uint8List(0);
  Uint8List _buffer = Uint8List(0);
  int _bufferStart = 0;
  int _totalCount = 0;
  int _index = 0;

  prepare(Uint8List data, [int bufferStart = 0, int? length]) {
    _buffer = data;
    if (length == null) {
      length = data.length;
    }
    _index = 0;
    _bufferStart = bufferStart;
    _totalCount = _putbackBuffer.length + length;
  }

  int get bytesLeft => _totalCount - _index;

  bool get hasNext => _index < _totalCount;

  int getNext() {
    final idx = _index;
    _index++;
    if (idx < _putbackBuffer.length) {
      return _putbackBuffer[idx];
    } else {
      return _buffer[_bufferStart + (idx - _putbackBuffer.length)];
    }
  }

  putback(int byte) {
    final left = bytesLeft;
    final newBuffer = Uint8List(left + 1);
    newBuffer[0] = byte;

    for (int i = 0; i < left; i++) {
      newBuffer[i + 1] = getNext();
    }
    _putbackBuffer = newBuffer;
  }

  done() {
    if (_index < _putbackBuffer.length) {
      final newPutback = Uint8List(_putbackBuffer.length - _index);
      for (int i = 0; i < newPutback.length; i++) {
        newPutback[i] = _putbackBuffer[i + _index];
      }
      _putbackBuffer = newPutback;
    } else {
      _putbackBuffer = Uint8List(0);
    }
  }

  reset() {
    _putbackBuffer = Uint8List(0);
    _index = 0;
  }
}
