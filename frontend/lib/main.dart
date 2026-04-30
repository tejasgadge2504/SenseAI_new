import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/language_provider.dart';
import 'services/connectivity_service.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ConnectivityService().init();

  // TEMP: Run once to clear old data that lacks checkedActions field, then remove
  // await StorageService.clearAll();

  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: const SenseApp(),
    ),
  );
}

class SenseApp extends StatelessWidget {
  const SenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lang, _) {
        return MaterialApp(
          title: 'SenseAI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,

          // 🌍 Language Configuration
          locale: lang.locale,
          supportedLocales: LanguageProvider.supportedLanguages.keys
              .map((code) => Locale(code))
              .toList(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          home: const HomeScreen(),
        );
      },
    );
  }
}