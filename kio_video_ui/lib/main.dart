import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'widgets/kio_sidebar.dart';
import 'screens/analyzer_screen.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final settingsService = SettingsService();
  await settingsService.init();

  runApp(KioVideoAnalyzerApp(settingsService: settingsService));
}

class KioVideoAnalyzerApp extends StatelessWidget {
  final SettingsService settingsService;
  const KioVideoAnalyzerApp({super.key, required this.settingsService});

  @override
  Widget build(BuildContext context) {
    const neonGreen = Color(0xFF55FC27);
    const darkBg = Color(0xFF121212);
    const surfaceColor = Color(0xFF1E1E1E);

    return MaterialApp(
      title: 'KIO Video Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        colorScheme: const ColorScheme.dark(
          primary: neonGreen,
          secondary: neonGreen,
          surface: surfaceColor,
          background: darkBg,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
          displayMedium: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
          titleLarge: TextStyle(fontWeight: FontWeight.w600),
        ),
        useMaterial3: true,
      ),
      home: MainLayout(settingsService: settingsService),
    );
  }
}

class MainLayout extends StatefulWidget {
  final SettingsService settingsService;
  const MainLayout({super.key, required this.settingsService});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = widget.settingsService.geminiApiKey;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _showSettingsDialog() {
    _apiKeyController.text = widget.settingsService.geminiApiKey;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Einstellungen', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Google Gemini API Key', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'AIzaSy...',
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF55FC27)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF55FC27), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Hole dir einen kostenlosen Key unter:\nhttps://aistudio.google.com/app/apikey',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF55FC27),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                await widget.settingsService.setGeminiApiKey(_apiKeyController.text.trim());
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('API Key gespeichert!'),
                      backgroundColor: Color(0xFF55FC27),
                    ),
                  );
                }
              },
              child: const Text('Speichern', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('KIO Video Analyzer', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF55FC27))),
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
            ),
      drawer: isDesktop
          ? null
          : Drawer(
              child: KioSidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: (index) {
                  setState(() => _selectedIndex = index);
                  Navigator.pop(context);
                },
                onSettingsTapped: _showSettingsDialog,
              ),
            ),
      body: Row(
        children: [
          if (isDesktop)
            KioSidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: (index) => setState(() => _selectedIndex = index),
              onSettingsTapped: _showSettingsDialog,
            ),
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return AnalyzerScreen(settingsService: widget.settingsService);
      case 1:
        return const Center(child: Text('Video-Upload (Demnächst verfügbar)', style: TextStyle(color: Colors.white54)));
      case 2:
        return const Center(child: Text('Video-Aufnahme (Demnächst verfügbar)', style: TextStyle(color: Colors.white54)));
      case 3:
        return AnalyzerScreen(settingsService: widget.settingsService);
      default:
        return AnalyzerScreen(settingsService: widget.settingsService);
    }
  }
}
