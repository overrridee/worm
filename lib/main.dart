import 'package:flutter/material.dart';

import 'controllers/app_controller.dart';
import 'screens/daily_words_screen.dart';
import 'screens/memorized_words_screen.dart';
import 'screens/practice_screen.dart';
import 'screens/quick_practice_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WormApp());
}

class WormApp extends StatelessWidget {
  const WormApp({super.key, this.controller});

  final AppController? controller;

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Worm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: baseScheme,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: baseScheme.primaryContainer,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
      home: WormHomePage(controller: controller),
    );
  }
}

class WormHomePage extends StatefulWidget {
  const WormHomePage({super.key, this.controller});

  final AppController? controller;

  @override
  State<WormHomePage> createState() => _WormHomePageState();
}

class _WormHomePageState extends State<WormHomePage> with WidgetsBindingObserver {
  late final AppController _controller;
  late final bool _ownsController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AppController();
    _controller.init(onNotificationTap: _handleNotificationTap);
  }

  void _handleNotificationTap(String payload) {
    if (!mounted) return;
    if (payload == NotificationService.payloadPractice) {
      setState(() => _selectedIndex = 1);
    } else if (payload == NotificationService.payloadDaily) {
      setState(() => _selectedIndex = 0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_controller.isLoading) {
      _controller.checkDayRolloverAndSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_controller.loadError != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 56,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _controller.loadError!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _controller.init(
                        onNotificationTap: _handleNotificationTap,
                      ),
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                DailyWordsScreen(controller: _controller),
                PracticeScreen(
                  controller: _controller,
                  isActiveTab: _selectedIndex == 1,
                ),
                QuickPracticeScreen(
                  controller: _controller,
                  isActiveTab: _selectedIndex == 2,
                ),
                MemorizedWordsScreen(controller: _controller),
                SettingsScreen(controller: _controller),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              if (_selectedIndex == 1 && index != 1) {
                _controller.tts.stop();
              }
              setState(() => _selectedIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.style_outlined),
                selectedIcon: Icon(Icons.style_rounded),
                label: 'Günlük',
              ),
              NavigationDestination(
                icon: Icon(Icons.headphones_outlined),
                selectedIcon: Icon(Icons.headphones_rounded),
                label: 'Pratik',
              ),
              NavigationDestination(
                icon: Icon(Icons.playlist_play_outlined),
                selectedIcon: Icon(Icons.playlist_play_rounded),
                label: 'Hızlı Pratik',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_border_rounded),
                selectedIcon: Icon(Icons.bookmark_rounded),
                label: 'Ezberlenen',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Ayarlar',
              ),
            ],
          ),
        );
      },
    );
  }
}
