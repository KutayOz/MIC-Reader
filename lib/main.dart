import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/history_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/user_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize providers with persisted data
  final localeProvider = LocaleProvider();
  final userProvider = UserProvider();
  final historyProvider = HistoryProvider();

  await Future.wait([
    localeProvider.init(),
    userProvider.init(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider.value(value: historyProvider),
      ],
      child: const MicReaderApp(),
    ),
  );
}
