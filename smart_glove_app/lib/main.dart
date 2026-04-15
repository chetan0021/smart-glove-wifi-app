import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ws_manager.dart';
import 'services/tts_service.dart';
import 'services/preferences_service.dart';
import 'state/glove_notifier.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartGloveApp());
}

class SmartGloveApp extends StatelessWidget {
  const SmartGloveApp({super.key});

  @override
  Widget build(BuildContext context) {
    final wsManager = WsManager();
    final ttsService = TtsService();
    final prefsService = PreferencesService();

    return MultiProvider(
      providers: [
        Provider<WsManager>.value(value: wsManager),
        ChangeNotifierProvider(
          create: (_) => GloveNotifier(wsManager, ttsService, prefsService),
        ),
      ],
      child: MaterialApp(
        title: 'SmartGlove',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blueAccent,
          useMaterial3: true,
          cardTheme: const CardThemeData(surfaceTintColor: Colors.transparent),
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
