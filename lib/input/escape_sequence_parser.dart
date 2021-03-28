import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

abstract class IDcsHandler {
  void hook(String collect, List<int> parameters, int flag);
  void put(Uint8List data, int start, int end);
  void unhook();
}

// Dummy DCS Handler as default fallback
class DcsDummy extends IDcsHandler {
  @override
  void hook(String collect, List<int> parameters, int flag) {}
  @override
  void put(Uint8List data, int start, int end) {}
  @override
  void unhook() {}
}

typedef CsiHandler = Function(List<int> parameters, String collect);
typedef OscHandler = Function(String data);
typedef EscHandler = Function(String collect, int flag);
typedef PrintHandler = Function(Uint8List data, int start, int end);
typedef ExecuteHandler = Function();

enum ParserAction {
  Ignore,
  Error,
  Print,
  Execute,
  OscStart,
  OscPut,
  OscEnd,
  CsiDispatch,
  Param,
  Collect,
  EscDispatch,
  Clear,
  DcsHook,
  DcsPut,
  DcsUnhook
}

extension ParserActionExtension on ParserAction {
  static bool _initialized = false;

  static Map<ParserAction, int> _parserActionValueMap = {
    ParserAction.Ignore: 0,
    ParserAction.Error: 1,
    ParserAction.Print: 2,
    ParserAction.Execute: 3,
    ParserAction.OscStart: 4,
    ParserAction.OscPut: 5,
    ParserAction.OscEnd: 6,
    ParserAction.CsiDispatch: 7,
    ParserAction.Param: 8,
    ParserAction.Collect: 9,
    ParserAction.EscDispatch: 10,
    ParserAction.Clear: 11,
    ParserAction.DcsHook: 12,
    ParserAction.DcsPut: 13,
    ParserAction.DcsUnhook: 14,
  };
  static late Map<int, ParserAction> _valueParserActionMap;

  static ensureInitialized() {
    if (_initialized) {
      return;
    }
    for (final entry in _parserActionValueMap.entries) {
      _valueParserActionMap[entry.value] = entry.key;
    }
    _initialized = true;
  }

  int get value {
    ensureInitialized();
    return _parserActionValueMap[this]!;
  }

  static ParserAction fromValue(int value) {
    ensureInitialized();
    return _valueParserActionMap[value]!;
  }
}

enum ParserState {
  Invalid,
  Ground,
  Escape,
  EscapeIntermediate,
  CsiEntry,
  CsiParam,
  CsiIntermediate,
  CsiIgnore,
  SosPmApcString,
  OscString,
  DcsEntry,
  DcsParam,
  DcsIgnore,
  DcsIntermediate,
  DcsPassthrough
}

extension ParserStateExtension on ParserState {
  static bool _initialized = false;

  static Map<ParserState, int> _parserStateValueMap = {
    ParserState.Invalid: -1,
    ParserState.Ground: 0,
    ParserState.Escape: 1,
    ParserState.EscapeIntermediate: 2,
    ParserState.CsiEntry: 3,
    ParserState.CsiParam: 4,
    ParserState.CsiIntermediate: 5,
    ParserState.CsiIgnore: 6,
    ParserState.SosPmApcString: 7,
    ParserState.OscString: 8,
    ParserState.DcsEntry: 9,
    ParserState.DcsParam: 10,
    ParserState.DcsIgnore: 11,
    ParserState.DcsIntermediate: 12,
    ParserState.DcsPassthrough: 13,
  };
  static late Map<int, ParserState> _valueParserStateMap;

  static ensureInitialized() {
    if (_initialized) {
      return;
    }
    for (final entry in _parserStateValueMap.entries) {
      _valueParserStateMap[entry.value] = entry.key;
    }
    _initialized = true;
  }

  int get value {
    ensureInitialized();
    return _parserStateValueMap[this]!;
  }

  static ParserState fromValue(int value) {
    ensureInitialized();
    return _valueParserStateMap[value]!;
  }
}

class ParsingState {
  /// <summary>
  /// Position in Parse String
  /// </summary>
  int position;

  /// <summary>
  /// Actual character code
  /// </summary>
  int code;

  /// <summary>
  /// Current Parser State
  /// </summary>
  ParserState currentState;

  /// <summary>
  /// Print buffer start index (-1 for not set)
  /// </summary>
  int print;

  /// <summary>
  ///  Buffer start index (-1 for not set)
  /// </summary>
  int dcs;

  /// <summary>
  /// Osc string buffer
  /// </summary>
  String osc;

  /// <summary>
  /// Collect buffer with intermediate characters
  /// </summary>
  String collect;

  /// <summary>
  /// Parameters buffer
  /// </summary>
  List<int>? parameters;
  // should abort (default: false)
  bool abort;

  ParsingState(
      {required this.position,
      required this.code,
      required this.currentState,
      required this.print,
      required this.dcs,
      required this.osc,
      required this.collect,
      this.parameters,
      this.abort = false});
}

class TransitionTable {
  Uint8List _table;

  TransitionTable(int length) : _table = Uint8List(length);

  add(int code, ParserState state, ParserAction action,
      [ParserState next = ParserState.Invalid]) {
    _table[state.value << 8 | code] = (action.value << 4 |
        (next == ParserState.Invalid ? state.value : next.value));
  }

  void addMultiple(List<int> codes, ParserState state, ParserAction action,
      [ParserState next = ParserState.Invalid]) {
    codes.forEach((element) {
      add(element, state, action, next);
    });
  }

  int operator [](int index) {
    return _table[index];
  }
}

class EscapeSequenceParser {
  static List<int> printables = r(0x20, 0x7f);
  static List<int> executables = r(0x00, 0x19) + r(0x1c, 0x20);

  static List<int> r(int low, int high) =>
      List<int>.generate(high - low, (index) => low + index);

  static List<ParserState> rp(ParserState low, ParserState high) =>
      List<ParserState>.generate(high.value - low.value,
          (index) => ParserStateExtension.fromValue(low.value + index));

  static const int NonAsciiPrintable = 0xa0;

  static TransitionTable buildVt500TransitionTable() {
    var table = new TransitionTable(4095);
    var states = rp(ParserState.Ground,
        ParserStateExtension.fromValue(ParserState.DcsPassthrough.value + 1));

    // table with default transition
    for (var state in states) {
      for (var code = 0; code <= NonAsciiPrintable; ++code) {
        table.add(code, state, ParserAction.Error, ParserState.Ground);
      }
    }
    // printables
    table.addMultiple(
        printables, ParserState.Ground, ParserAction.Print, ParserState.Ground);

    // global anwyhere rules
    for (var state in states) {
      table.addMultiple([0x18, 0x1a, 0x99, 0x9a], state, ParserAction.Execute,
          ParserState.Ground);
      table.addMultiple(
          r(0x80, 0x90), state, ParserAction.Execute, ParserState.Ground);
      table.addMultiple(
          r(0x90, 0x98), state, ParserAction.Execute, ParserState.Ground);
      table.add(0x9c, state, ParserAction.Ignore,
          ParserState.Ground); // ST as terminator
      table.add(0x1b, state, ParserAction.Clear, ParserState.Escape); // ESC
      table.add(
          0x9d, state, ParserAction.OscStart, ParserState.OscString); // OSC
      table.addMultiple([0x98, 0x9e, 0x9f], state, ParserAction.Ignore,
          ParserState.SosPmApcString);
      table.add(0x9b, state, ParserAction.Clear, ParserState.CsiEntry); // CSI
      table.add(0x90, state, ParserAction.Clear, ParserState.DcsEntry); // DCS
    }

    // rules for executable and 0x7f
    table.addMultiple(executables, ParserState.Ground, ParserAction.Execute,
        ParserState.Ground);
    table.addMultiple(executables, ParserState.Escape, ParserAction.Execute,
        ParserState.Escape);
    table.add(
        0x7f, ParserState.Escape, ParserAction.Ignore, ParserState.Escape);
    table.addMultiple(executables, ParserState.OscString, ParserAction.Ignore,
        ParserState.OscString);
    table.addMultiple(executables, ParserState.CsiEntry, ParserAction.Execute,
        ParserState.CsiEntry);
    table.add(
        0x7f, ParserState.CsiEntry, ParserAction.Ignore, ParserState.CsiEntry);
    table.addMultiple(executables, ParserState.CsiParam, ParserAction.Execute,
        ParserState.CsiParam);
    table.add(
        0x7f, ParserState.CsiParam, ParserAction.Ignore, ParserState.CsiParam);
    table.addMultiple(executables, ParserState.CsiIgnore, ParserAction.Execute,
        ParserState.CsiIgnore);
    table.addMultiple(executables, ParserState.CsiIntermediate,
        ParserAction.Execute, ParserState.CsiIntermediate);
    table.add(0x7f, ParserState.CsiIntermediate, ParserAction.Ignore,
        ParserState.CsiIntermediate);
    table.addMultiple(executables, ParserState.EscapeIntermediate,
        ParserAction.Execute, ParserState.EscapeIntermediate);
    table.add(0x7f, ParserState.EscapeIntermediate, ParserAction.Ignore,
        ParserState.EscapeIntermediate);
    // osc
    table.add(
        0x5d, ParserState.Escape, ParserAction.OscStart, ParserState.OscString);
    table.addMultiple(executables, ParserState.OscString, ParserAction.OscPut,
        ParserState.OscString);
    table.add(0x7f, ParserState.OscString, ParserAction.OscPut,
        ParserState.OscString);
    table.addMultiple([0x9c, 0x1b, 0x18, 0x1a, 0x07], ParserState.OscString,
        ParserAction.OscEnd, ParserState.Ground);
    table.addMultiple(r(0x1c, 0x20), ParserState.OscString, ParserAction.Ignore,
        ParserState.OscString);
    // sos/pm/apc does nothing
    table.addMultiple([0x58, 0x5e, 0x5f], ParserState.Escape,
        ParserAction.Ignore, ParserState.SosPmApcString);
    table.addMultiple(printables, ParserState.SosPmApcString,
        ParserAction.Ignore, ParserState.SosPmApcString);
    table.addMultiple(executables, ParserState.SosPmApcString,
        ParserAction.Ignore, ParserState.SosPmApcString);
    table.add(0x9c, ParserState.SosPmApcString, ParserAction.Ignore,
        ParserState.Ground);
    table.add(0x7f, ParserState.SosPmApcString, ParserAction.Ignore,
        ParserState.SosPmApcString);
    // csi entries
    table.add(
        0x5b, ParserState.Escape, ParserAction.Clear, ParserState.CsiEntry);
    table.addMultiple(r(0x40, 0x7f), ParserState.CsiEntry,
        ParserAction.CsiDispatch, ParserState.Ground);
    table.addMultiple(r(0x30, 0x3a), ParserState.CsiEntry, ParserAction.Param,
        ParserState.CsiParam);
    table.add(
        0x3b, ParserState.CsiEntry, ParserAction.Param, ParserState.CsiParam);
    table.addMultiple([0x3c, 0x3d, 0x3e, 0x3f], ParserState.CsiEntry,
        ParserAction.Collect, ParserState.CsiParam);
    table.addMultiple(r(0x30, 0x3a), ParserState.CsiParam, ParserAction.Param,
        ParserState.CsiParam);
    table.add(
        0x3b, ParserState.CsiParam, ParserAction.Param, ParserState.CsiParam);
    table.addMultiple(r(0x40, 0x7f), ParserState.CsiParam,
        ParserAction.CsiDispatch, ParserState.Ground);
    table.addMultiple([0x3a, 0x3c, 0x3d, 0x3e, 0x3f], ParserState.CsiParam,
        ParserAction.Ignore, ParserState.CsiIgnore);
    table.addMultiple(r(0x20, 0x40), ParserState.CsiIgnore, ParserAction.Ignore,
        ParserState.CsiIgnore);
    table.add(0x7f, ParserState.CsiIgnore, ParserAction.Ignore,
        ParserState.CsiIgnore);
    table.addMultiple(r(0x40, 0x7f), ParserState.CsiIgnore, ParserAction.Ignore,
        ParserState.Ground);
    table.add(
        0x3a, ParserState.CsiEntry, ParserAction.Ignore, ParserState.CsiIgnore);
    table.addMultiple(r(0x20, 0x30), ParserState.CsiEntry, ParserAction.Collect,
        ParserState.CsiIntermediate);
    table.addMultiple(r(0x20, 0x30), ParserState.CsiIntermediate,
        ParserAction.Collect, ParserState.CsiIntermediate);
    table.addMultiple(r(0x30, 0x40), ParserState.CsiIntermediate,
        ParserAction.Ignore, ParserState.CsiIgnore);
    table.addMultiple(r(0x40, 0x7f), ParserState.CsiIntermediate,
        ParserAction.CsiDispatch, ParserState.Ground);
    table.addMultiple(r(0x20, 0x30), ParserState.CsiParam, ParserAction.Collect,
        ParserState.CsiIntermediate);
    // escIntermediate
    table.addMultiple(r(0x20, 0x30), ParserState.Escape, ParserAction.Collect,
        ParserState.EscapeIntermediate);
    table.addMultiple(r(0x20, 0x30), ParserState.EscapeIntermediate,
        ParserAction.Collect, ParserState.EscapeIntermediate);
    table.addMultiple(r(0x30, 0x7f), ParserState.EscapeIntermediate,
        ParserAction.EscDispatch, ParserState.Ground);
    table.addMultiple(r(0x30, 0x50), ParserState.Escape,
        ParserAction.EscDispatch, ParserState.Ground);
    table.addMultiple(r(0x51, 0x58), ParserState.Escape,
        ParserAction.EscDispatch, ParserState.Ground);
    table.addMultiple([0x59, 0x5a, 0x5c], ParserState.Escape,
        ParserAction.EscDispatch, ParserState.Ground);
    table.addMultiple(r(0x60, 0x7f), ParserState.Escape,
        ParserAction.EscDispatch, ParserState.Ground);
    // dcs entry
    table.add(
        0x50, ParserState.Escape, ParserAction.Clear, ParserState.DcsEntry);
    table.addMultiple(executables, ParserState.DcsEntry, ParserAction.Ignore,
        ParserState.DcsEntry);
    table.add(
        0x7f, ParserState.DcsEntry, ParserAction.Ignore, ParserState.DcsEntry);
    table.addMultiple(r(0x1c, 0x20), ParserState.DcsEntry, ParserAction.Ignore,
        ParserState.DcsEntry);
    table.addMultiple(r(0x20, 0x30), ParserState.DcsEntry, ParserAction.Collect,
        ParserState.DcsIntermediate);
    table.add(
        0x3a, ParserState.DcsEntry, ParserAction.Ignore, ParserState.DcsIgnore);
    table.addMultiple(r(0x30, 0x3a), ParserState.DcsEntry, ParserAction.Param,
        ParserState.DcsParam);
    table.add(
        0x3b, ParserState.DcsEntry, ParserAction.Param, ParserState.DcsParam);
    table.addMultiple([0x3c, 0x3d, 0x3e, 0x3f], ParserState.DcsEntry,
        ParserAction.Collect, ParserState.DcsParam);
    table.addMultiple(executables, ParserState.DcsIgnore, ParserAction.Ignore,
        ParserState.DcsIgnore);
    table.addMultiple(r(0x20, 0x80), ParserState.DcsIgnore, ParserAction.Ignore,
        ParserState.DcsIgnore);
    table.addMultiple(r(0x1c, 0x20), ParserState.DcsIgnore, ParserAction.Ignore,
        ParserState.DcsIgnore);
    table.addMultiple(executables, ParserState.DcsParam, ParserAction.Ignore,
        ParserState.DcsParam);
    table.add(
        0x7f, ParserState.DcsParam, ParserAction.Ignore, ParserState.DcsParam);
    table.addMultiple(r(0x1c, 0x20), ParserState.DcsParam, ParserAction.Ignore,
        ParserState.DcsParam);
    table.addMultiple(r(0x30, 0x3a), ParserState.DcsParam, ParserAction.Param,
        ParserState.DcsParam);
    table.add(
        0x3b, ParserState.DcsParam, ParserAction.Param, ParserState.DcsParam);
    table.addMultiple([0x3a, 0x3c, 0x3d, 0x3e, 0x3f], ParserState.DcsParam,
        ParserAction.Ignore, ParserState.DcsIgnore);
    table.addMultiple(r(0x20, 0x30), ParserState.DcsParam, ParserAction.Collect,
        ParserState.DcsIntermediate);
    table.addMultiple(executables, ParserState.DcsIntermediate,
        ParserAction.Ignore, ParserState.DcsIntermediate);
    table.add(0x7f, ParserState.DcsIntermediate, ParserAction.Ignore,
        ParserState.DcsIntermediate);
    table.addMultiple(r(0x1c, 0x20), ParserState.DcsIntermediate,
        ParserAction.Ignore, ParserState.DcsIntermediate);
    table.addMultiple(r(0x20, 0x30), ParserState.DcsIntermediate,
        ParserAction.Collect, ParserState.DcsIntermediate);
    table.addMultiple(r(0x30, 0x40), ParserState.DcsIntermediate,
        ParserAction.Ignore, ParserState.DcsIgnore);
    table.addMultiple(r(0x40, 0x7f), ParserState.DcsIntermediate,
        ParserAction.DcsHook, ParserState.DcsPassthrough);
    table.addMultiple(r(0x40, 0x7f), ParserState.DcsParam, ParserAction.DcsHook,
        ParserState.DcsPassthrough);
    table.addMultiple(r(0x40, 0x7f), ParserState.DcsEntry, ParserAction.DcsHook,
        ParserState.DcsPassthrough);
    table.addMultiple(executables, ParserState.DcsPassthrough,
        ParserAction.DcsPut, ParserState.DcsPassthrough);
    table.addMultiple(printables, ParserState.DcsPassthrough,
        ParserAction.DcsPut, ParserState.DcsPassthrough);
    table.add(0x7f, ParserState.DcsPassthrough, ParserAction.Ignore,
        ParserState.DcsPassthrough);
    table.addMultiple([0x1b, 0x9c], ParserState.DcsPassthrough,
        ParserAction.DcsUnhook, ParserState.Ground);
    table.add(NonAsciiPrintable, ParserState.OscString, ParserAction.OscPut,
        ParserState.OscString);

    return table;
  }

  // Handler lookup container
  final csiHandlers = Map<int, List<CsiHandler>>();
  final oscHandlers = Map<int, List<OscHandler>>();
  final executeHandlers = Map<int, ExecuteHandler>();
  final escHandlers = Map<String, EscHandler>();
  final dcsHandlers = Map<String, IDcsHandler>();
  IDcsHandler? activeDcsHandler;
  late ParsingState Function(ParsingState) errorHandler;

  ParserState initialState, currentState;

  static void emptyExecuteHandler(int code) {}

  static ParsingState emptyErrorHandler(ParsingState state) => state;

  // Fallback handlers
  PrintHandler printHandlerFallback = (data, start, end) => {};
  Function(int) executeHandlerFallback = emptyExecuteHandler;
  Function(String, List<int>, int) csiHandlerFallback =
      (collect, parameters, flag) =>
          {print('Can not handle ESC-[' + String.fromCharCode(flag))};
  EscHandler escHandlerFallback = (collect, flag) => {};
  Function(int, String) oscHandlerFallback = (identifier, data) => {};
  IDcsHandler dcsHandlerFallback = new DcsDummy();
  ParsingState Function(ParsingState) errorHandlerFallback = (state) => state;

  // buffers over several parser calls
  var _osc = '';
  var _pars = [0];
  var _collect = '';
  PrintHandler printHandler = (data, start, end) => {};
  Function() printStateReset = () => {};

  TransitionTable _table;
  EscapeSequenceParser()
      : _table = buildVt500TransitionTable(),
        initialState = ParserState.Ground,
        currentState = ParserState.Ground {
    errorHandler = errorHandlerFallback;
    setEscHandler('\\', escHandlerFallback);
  }

  void setPrintHandler(PrintHandler printHandler) =>
      this.printHandler = printHandler;
  void clearPrintHandler() => printHandler = printHandlerFallback;

  void setExecuteHandler(int flag, ExecuteHandler handler) =>
      executeHandlers[flag] = handler;
  void clearExecuteHandler(int flag) => executeHandlers.remove(flag);
  void setExecuteHandlerFallback(Function(int) fallback) =>
      executeHandlerFallback = fallback;

  void setEscHandler(String flag, EscHandler callback) =>
      escHandlers[flag] = callback;
  void clearEscHandler(String flag) => escHandlers.remove(flag);
  void setEscHandlerFallback(EscHandler fallback) =>
      escHandlerFallback = fallback;

  void setCsiHandler(String flag, CsiHandler callback) =>
      csiHandlers[flag.runes.first] = [callback];
  void clearCsiHandler(int flag) => csiHandlers.remove(flag);
  void setCsiHandlerFallback(Function(String, List<int>, int) fallback) =>
      csiHandlerFallback = fallback;

  void setOscHandler(int identifier, OscHandler callback) =>
      oscHandlers[identifier] = [callback];
  void clearOscHandler(int identifier) => oscHandlers.remove(identifier);
  void setOscHandlerFallback(Function(int, String) fallback) =>
      oscHandlerFallback = fallback;

  void setDcsHandler(String flag, IDcsHandler handler) =>
      dcsHandlers[flag] = handler;
  void clearDcsHandler(String flag) => dcsHandlers.remove(flag);
  void setDcsHandlerFallback(IDcsHandler fallback) =>
      dcsHandlerFallback = fallback;

  void setErrorHandler(ParsingState Function(ParsingState) errorHandler) =>
      errorHandler = errorHandler;
  void clearErrorHandler() => errorHandler = emptyErrorHandler;

  void reset() {
    currentState = initialState;
    _osc = '';
    _pars.clear();
    _pars.add(0);
    _collect = '';
    activeDcsHandler = null;
    printStateReset();
  }

  void parse(Uint8List data) {
    final utf8Dec = Utf8Decoder(allowMalformed: true);
    int code = 0;
    var transition = 0;
    var error = false;
    var currentState = this.currentState;
    var print = -1;
    var dcs = -1;
    var osc = this._osc;
    var collect = this._collect;
    var pars = this._pars;
    var dcsHandler = activeDcsHandler;

    // process input string
    for (var i = 0; i < data.length; ++i) {
      code = data[i];

      // This version eliminates the check for < 0x80, as we allow any UTF8 sequences.
      if (currentState == ParserState.Ground && code > 0x1f) {
        print = (~print != 0) ? print : i;
        do {
          i++;
        } while (i < data.length && data[i] > 0x1f);
        i--;
        continue;
      }

      // shorcut for CSI params
      if (currentState == ParserState.CsiParam &&
          (code > 0x2f && code < 0x39)) {
        pars[pars.length - 1] = pars[pars.length - 1] * 10 + code - 48;
        continue;
      }

      // Normal transition and action lookup
      transition = _table[
          currentState.value << 8 | (code < 0xa0 ? code : NonAsciiPrintable)];
      var action = ParserActionExtension.fromValue(transition >> 4);
      switch (action) {
        case ParserAction.Print:
          print = (~print != 0) ? print : i;
          break;
        case ParserAction.Execute:
          if (~print != 0) {
            printHandler(data, print, i);
            print = -1;
          }
          final callback = executeHandlers[code];
          if (callback != null)
            callback();
          else
            executeHandlerFallback(code);
          break;
        case ParserAction.Ignore:
          // handle leftover print or dcs chars
          if (~print != 0) {
            printHandler(data, print, i);
            print = -1;
          } else if (~dcs != 0) {
            dcsHandler?.put(data, dcs, i);
            dcs = -1;
          }
          break;
        case ParserAction.Error:
          // chars higher than 0x9f are handled by this action
          // to keep the transition table small
          if (code > 0x9f) {
            switch (currentState) {
              case ParserState.Ground:
                print = (~print != 0) ? print : i;
                break;
              case ParserState.CsiIgnore:
                transition |= ParserState.CsiIgnore.value;
                break;
              case ParserState.DcsIgnore:
                transition |= ParserState.DcsIgnore.value;
                break;
              case ParserState.DcsPassthrough:
                dcs = (~dcs != 0) ? dcs : i;
                transition |= ParserState.DcsPassthrough.value;
                break;
              default:
                error = true;
                break;
            }
          } else {
            error = true;
          }
          // if we end up here a real error happened
          if (error) {
            var inject = errorHandler(ParsingState(
                position: i,
                code: code,
                currentState: currentState,
                print: print,
                dcs: dcs,
                osc: osc,
                collect: collect));
            if (inject.abort) return;
            error = false;
          }
          break;
        case ParserAction.CsiDispatch:
          // Trigger CSI handler
          final csiHandlers = this.csiHandlers[code];
          if (csiHandlers != null) {
            var jj = csiHandlers.length - 1;
            for (; jj >= 0; jj--) {
              csiHandlers[jj](pars, collect);
            }
          } else
            csiHandlerFallback(collect, pars, code);
          break;
        case ParserAction.Param:
          if (code == 0x3b)
            pars.add(0);
          else
            pars[pars.length - 1] = pars[pars.length - 1] * 10 + code - 48;
          break;
        case ParserAction.Collect:
          // AUDIT: make collect a ustring
          collect += String.fromCharCode(code);
          break;
        case ParserAction.EscDispatch:
          final ehandler = escHandlers[code];
          if (ehandler != null)
            ehandler(collect, code);
          else
            escHandlerFallback(collect, code);
          break;
        case ParserAction.Clear:
          if (~print != 0) {
            printHandler(data, print, i);
            print = -1;
          }
          osc = '';
          pars.clear();
          pars.add(0);
          collect = '';
          dcs = -1;
          printStateReset();
          break;
        case ParserAction.DcsHook:
          final dcsHandler = dcsHandlers[code];
          if (dcsHandler != null)
            dcsHandler.hook(collect, pars, code);
          else
            dcsHandlerFallback.hook(collect, pars, code);
          break;
        case ParserAction.DcsPut:
          dcs = (~dcs != 0) ? dcs : i;
          break;
        case ParserAction.DcsUnhook:
          if (dcsHandler != null) {
            if (~dcs != 0) dcsHandler.put(data, dcs, i);
            dcsHandler.unhook();
            dcsHandler = null;
          }
          if (code == 0x1b) transition |= ParserState.Escape.value;
          osc = '';
          pars.clear();
          pars.add(0);
          collect = '';
          dcs = -1;
          printStateReset();
          break;
        case ParserAction.OscStart:
          if (~print != 0) {
            printHandler(data, print, i);
            print = -1;
          }
          osc = '';
          break;
        case ParserAction.OscPut:
          for (var j = i;; j++) {
            if (j > data.length ||
                (data[j] < 0x20) ||
                (data[j] > 0x7f && data[j] < 0x9f)) {
              var block = Uint8List(j - (i + 1));
              for (int k = i + 1; k < j; k++) block[k - i - 1] = data[k];
              osc += utf8Dec.convert(block.toList(growable: false));

              i = j - 1;
              break;
            }
          }
          break;
        case ParserAction.OscEnd:
          if (osc != '' && code != 0x18 && code != 0x1a) {
            // NOTE: OSC subparsing is not part of the original parser
            // we do basic identifier parsing here to offer a jump table for OSC as well
            int idx = osc.indexOf(';');
            if (idx == -1) {
              oscHandlerFallback(-1, osc); // this is an error mal-formed OSC
            } else {
              // Note: NaN is not handled here
              // either catch it with the fallback handler
              // or with an explicit NaN OSC handler
              int identifier = int.tryParse(osc.substring(0, idx)) ?? 0;
              var content = osc.substring(idx + 1);
              // Trigger OSC handler
              int c = -1;
              final ohandlers = oscHandlers[identifier];
              if (ohandlers != null) {
                c = ohandlers.length - 1;
                for (; c >= 0; c--) {
                  ohandlers[c](content);
                  break;
                }
              }
              if (c < 0) oscHandlerFallback(identifier, content);
            }
          }
          if (code == 0x1b) transition |= ParserState.Escape.value;
          osc = '';
          pars.clear();
          pars.add(0);
          collect = '';
          dcs = -1;
          printStateReset();
          break;
      }
      currentState = ParserStateExtension.fromValue(transition & 15);
    }
    // push leftover pushable buffers to terminal
    if (currentState == ParserState.Ground && (~print != 0)) {
      printHandler(data, print, data.length);
    } else if (currentState == ParserState.DcsPassthrough &&
        (~dcs != 0) &&
        dcsHandler != null) {
      dcsHandler.put(data, dcs, data.length);
    }

    // save non pushable buffers
    _osc = osc;
    _collect = collect;
    _pars = pars;

    // save active dcs handler reference
    activeDcsHandler = dcsHandler;

    // save state
    this.currentState = currentState;
  }
}
