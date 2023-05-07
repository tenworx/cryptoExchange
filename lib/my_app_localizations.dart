import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class MyAppLocalizations {
  final Locale locale;

  MyAppLocalizations(this.locale);

  static MyAppLocalizations? of(BuildContext context) {
    return Localizations.of<MyAppLocalizations>(context, MyAppLocalizations);
  }

  Map<String, String>? _localizedStrings;

  Future<bool> load() async {
    // Load the language JSON file from the "l10n" folder
    String jsonString =
        await rootBundle.loadString('l10n/intl_${locale.languageCode}.arb');

    // Parse the JSON file and convert it into a Map
    Map<String, dynamic> jsonMap = json.decode(jsonString);
    _localizedStrings =
        jsonMap.map((key, value) => MapEntry(key, value.toString()));

    return true;
  }

  // This method will be called from every widget which needs a localized text
  String translate(String key) {
    return _localizedStrings![key]!;
  }

  // This is a helper method that will make it easier to access the localized strings
  // using the MyAppLocalizations.of(context).translate("key") syntax
  static const LocalizationsDelegate<MyAppLocalizations> delegate =
      _MyAppLocalizationsDelegate();
}

class _MyAppLocalizationsDelegate
    extends LocalizationsDelegate<MyAppLocalizations> {
  const _MyAppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fr', 'es'].contains(locale.languageCode);
  }

  @override
  Future<MyAppLocalizations> load(Locale locale) async {
    MyAppLocalizations localizations = MyAppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_MyAppLocalizationsDelegate old) => false;
}
