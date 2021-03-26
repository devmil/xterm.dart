import 'package:xterm/buffer/buffer.dart';
import 'package:xterm/buffer/buffer_line.dart';
import 'package:xterm/util/circular_list.dart';

abstract class ReflowStrategy {
  final Buffer _buffer;

  ReflowStrategy(this._buffer);

  Buffer get buffer => _buffer;

  void reflow(int newCols, int newRows, int oldCols, int oldRows);

  static int getWrappedLineTrimmedLengthFromCircularList(
      CircularList<BufferLine> lines, int row, int cols) {
    return getWrappedLineTrimmedLengthFromLine(
        lines[row], row == lines.length - 1 ? null : lines[row + 1], cols);
  }

  static int getWrappedLineTrimmedLengthFromLines(
      List<BufferLine> lines, int row, int cols) {
    return getWrappedLineTrimmedLengthFromLine(
        lines[row], row == lines.length - 1 ? null : lines[row + 1], cols);
  }

  static int getWrappedLineTrimmedLengthFromLine(
      BufferLine? line, BufferLine? nextLine, int cols) {
    if (line == null) {
      return 0;
    }
    if (nextLine == null) {
      return line.trimmedLength;
    }

    // Detect whether the following line starts with a wide character and the end of the current line
    // is null, if so then we can be pretty sure the null character should be excluded from the line
    // length]
    final endsInNull =
        !(line.hasContent(cols - 1)) && line.widthAt(cols - 1) == 1;
    final followingLineStartsWithWide = nextLine.widthAt(0) == 2;

    if (endsInNull && followingLineStartsWithWide) {
      return cols - 1;
    }
    return cols;
  }
}
