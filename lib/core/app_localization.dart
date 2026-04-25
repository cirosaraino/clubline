import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class ClublineLocalization {
  static const Locale italian = Locale('it', 'IT');

  static const List<Locale> supportedLocales = [italian];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
