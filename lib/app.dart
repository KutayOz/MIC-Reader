import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/locale_provider.dart';
import 'providers/user_provider.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';

class MicReaderApp extends StatelessWidget {
  const MicReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocaleProvider, UserProvider>(
      builder: (context, localeProvider, userProvider, child) {
        return MaterialApp(
          title: 'MIC Reader',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          locale: localeProvider.locale,
          supportedLocales: const [
            Locale('en'),
            Locale('tr'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: userProvider.isFirstRun
              ? const OnboardingScreen()
              : const HomeScreen(),
        );
      },
    );
  }
}
