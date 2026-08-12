import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'widgets/kio_sidebar.dart';
import 'screens/analyzer_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const KioVideoAnalyzerApp());
}

class KioVideoAnalyzerApp extends StatelessWidget {
  const KioVideoAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const neonGreen = Color(0xFF55FC27);
    const darkBg = Color(0xFF121212);
    const surfaceColor = Color(0xFF1E1E1E);

    return MaterialApp(
      title: 'KIO Video Analyzer UI',
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
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  void _showSettingsDialog() {
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
              const Text('Dieser Key wird später für die echte KI-Analyse benötigt.', style: TextStyle(fontSize: 12, color: Colors.white38)),
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
              onPressed: () => Navigator.pop(context),
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
      case 3:
        return const AnalyzerScreen();
      case 1:
        return const Center(child: Text('Video-Upload (Demnächst verfügbar)', style: TextStyle(color: Colors.white54)));
      case 2:
        return const Center(child: Text('Video-Aufnahme (Demnächst verfügbar)', style: TextStyle(color: Colors.white54)));
      default:
        return const AnalyzerScreen();
    }
  }
}
