import 'dart:convert';
import 'dart:typed_data';

import 'package:xterm/buffer/char_attribute_utils.dart';
import 'package:xterm/input/escape_sequence_parser.dart';
import 'package:xterm/xterm.dart';

class DECRQSS implements IDcsHandler {
  Terminal _terminal;
  List<int> _data = List<int>.empty(growable: true);
  final utf8Decoder = Utf8Decoder();

  DECRQSS(this._terminal);

  @override
  void hook(String collect, List<int> parameters, int flag) {
    _data = List<int>.empty(growable: true);
  }

  @override
  void put(Uint8List data, int start, int end) {
    for (int i = start; i < end; i++) _data.add(data[i]);
  }

  @override
  void unhook() {
    var newData = utf8Decoder.convert(_data);
    int ok =
        1; // 0 means the request is valid according to docs, but tests expect 0?
    String? result;

    switch (newData) {
      case "\"q": // DECCSA - Set Character Attribute
        result = "\"q";
        return;
      case "\"p": // DECSCL - conformance level
        result = "65;1\"p";
        break;
      case "r": // DECSTBM - the top and bottom margins
        result =
            "${_terminal.buffer.scrollTop + 1};{terminal.Buffer.ScrollBottom + 1}r";
        break;
      case "m": // SGR- the set graphic rendition
        // TODO: report real settings instead of 0m
        result = CharAttributeUtils.toSGR(_terminal.curAttr);
        break;
      case "s": // DECSLRM - the current left and right margins
        result =
            "${_terminal.buffer.marginLeft + 1};${_terminal.buffer.marginRight + 1}s";
        break;
      case " q": // DECSCUSR - the set cursor style
        // TODO this should send a number for the current cursor style 2 for block, 4 for underline and 6 for bar
        var style = "2"; // block
        result = "$style q";
        break;
      default:
        ok = 0; // this means the request is not valid, report that to the host.
        result = '';
        // invalid: DCS 0 $ r Pt ST (xterm)
        _terminal.error("Unknown DCS + $newData");
        break;
    }

    _terminal.sendResponse(
        "${_terminal.controlCodes.dcs}$ok\$r$result${_terminal.controlCodes.st}");
  }
}
