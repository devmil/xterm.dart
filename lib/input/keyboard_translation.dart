typedef TranslateFunc = String Function(
    bool shift, bool control, bool alt, bool mac, bool app);

class KeyboardTranslation {
  final String? normal;
  final String? shift;
  final String? control;
  final String? alt;
  final String? applicationMode;
  final TranslateFunc? translateFunc;

  KeyboardTranslation(
      {this.normal,
      this.shift,
      this.control,
      this.alt,
      this.applicationMode,
      this.translateFunc});
}
