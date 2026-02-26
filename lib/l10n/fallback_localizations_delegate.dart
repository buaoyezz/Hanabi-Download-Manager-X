import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Fallback delegate for FluentLocalizations to support custom locales
class FallbackFluentLocalizationsDelegate
    extends LocalizationsDelegate<fluent.FluentLocalizations> {
  const FallbackFluentLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<fluent.FluentLocalizations> load(Locale locale) async {
    // For custom locales, fall back to English
    if (locale.languageCode != 'en' && locale.languageCode != 'zh') {
      return fluent.FluentLocalizations.delegate.load(const Locale('en'));
    }
    return fluent.FluentLocalizations.delegate.load(locale);
  }

  @override
  bool shouldReload(FallbackFluentLocalizationsDelegate old) => false;
}

/// Fallback delegate for MaterialLocalizations to support custom locales
class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // For custom locales, fall back to English
    if (locale.languageCode != 'en' && locale.languageCode != 'zh') {
      return GlobalMaterialLocalizations.delegate.load(const Locale('en'));
    }
    return GlobalMaterialLocalizations.delegate.load(locale);
  }

  @override
  bool shouldReload(FallbackMaterialLocalizationsDelegate old) => false;
}

/// Fallback delegate for CupertinoLocalizations to support custom locales
class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    // For custom locales, fall back to English
    if (locale.languageCode != 'en' && locale.languageCode != 'zh') {
      return GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
    }
    return GlobalCupertinoLocalizations.delegate.load(locale);
  }

  @override
  bool shouldReload(FallbackCupertinoLocalizationsDelegate old) => false;
}
