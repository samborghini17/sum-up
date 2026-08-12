import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import '../services/pdf_export_service.dart';

class VideoChapter {
  final String title;
  final Duration time;
  final String priority; // 'high', 'medium', 'low'

  VideoChapter(this.title, this.time, this.priority);
}

class AnalyzerScreen extends StatefulWidget {
  const AnalyzerScreen({super.key});

  @override
  State<AnalyzerScreen> createState() => _AnalyzerScreenState();
}

class _AnalyzerScreenState extends State<AnalyzerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final player = Player();
  late final controller = VideoController(player);
  String? _videoPath;
  String? _videoName;
  Duration _videoDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  List<StreamSubscription> _subscriptions = [];

  final List<VideoChapter> _dummyChapters = [
    VideoChapter('Grundlagen wissenschaftlicher Aussagen', const Duration(minutes: 1, seconds: 40), 'high'),
    VideoChapter('Forschungslücke motivieren', const Duration(minutes: 4, seconds: 18), 'medium'),
    VideoChapter('Primär- vs. Sekundärquellen', const Duration(minutes: 5, seconds: 20), 'high'),
    VideoChapter('Direkte vs. indirekte Zitate', const Duration(minutes: 7, seconds: 32), 'low'),
    VideoChapter('Aufbau einer Arbeit (Kap. 1-6)', const Duration(minutes: 9, seconds: 50), 'high'),
    VideoChapter('Trennung von Rohdaten & Interpretation', const Duration(minutes: 15, seconds: 27), 'high'),
    VideoChapter('Literaturrecherche & CRAAP-Test', const Duration(minutes: 30, seconds: 28), 'high'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    _subscriptions.add(player.stream.duration.listen((duration) {
      if (mounted) setState(() => _videoDuration = duration);
    }));
    _subscriptions.add(player.stream.position.listen((position) {
      if (mounted) setState(() => _currentPosition = position);
    }));
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    player.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _videoPath = result.files.single.path!;
        _videoName = result.files.single.name;
        // Mock a 1 hour duration if local file doesn't load length instantly for UI demo
        _videoDuration = const Duration(hours: 1, minutes: 20); 
      });
      player.open(Media(_videoPath!));
    }
  }

  Future<void> _exportPdf() async {
    if (_videoName == null) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generiere PDF...')));
      final path = await PdfExportService.generateAndSavePdf(
        videoName: _videoName!,
        summary: 'Das Video vermittelt fundamentale Grundlagen des wissenschaftlichen Arbeitens, der Literaturrecherche und des Aufbaus akademischer Arbeiten. Reproduzierbarkeit und Objektivität stehen im Vordergrund.',
        timestamps: _dummyChapters.map((c) {
          final mins = c.time.inMinutes.toString().padLeft(2, '0');
          final secs = (c.time.inSeconds % 60).toString().padLeft(2, '0');
          return {'time': '$mins:$secs', 'title': c.title};
        }).toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF erfolgreich exportiert nach:\n$path'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim PDF Export: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1024;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Content (Video Player & Timeline)
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildVideoPlayer(),
                const SizedBox(height: 16),
                if (_videoPath != null) _buildInteractiveTimeline(),
                const SizedBox(height: 24),
                _buildQuickActions(),
              ],
            ),
          ),
        ),
        // Right Panel (Tabs)
        if (isDesktop)
          Expanded(
            flex: 4,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF55FC27),
                    labelColor: const Color(0xFF55FC27),
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(text: 'Analyse'),
                      Tab(text: 'Lern-Tools'),
                      Tab(text: 'Gamification'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAnalysisTab(),
                        _buildLearningToolsTab(),
                        _buildGamificationTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'AKTUELLES VIDEO',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white54),
            ),
            if (_videoName != null)
               TextButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.loop, color: Color(0xFF55FC27), size: 16),
                label: const Text('Neues Video', style: TextStyle(color: Color(0xFF55FC27))),
              )
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _videoName ?? 'Kein Video ausgewählt',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        if (_videoName == null)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF55FC27).withOpacity(0.2),
              foregroundColor: const Color(0xFF55FC27),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: _pickVideo,
            icon: const Icon(Icons.upload_file),
            label: const Text('Video auswählen'),
          ),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF55FC27).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, spreadRadius: 5)
          ]
        ),
        clipBehavior: Clip.antiAlias,
        child: _videoPath != null
            ? Video(controller: controller)
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF55FC27).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 48, color: Color(0xFF55FC27)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Wähle ein Video zum Abspielen aus', style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInteractiveTimeline() {
    if (_videoDuration.inSeconds == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('KAPITEL & THEMEN (Priorisiert nach Prüfungsrelevanz)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            return Container(
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Progress Bar
                  Container(
                    width: width * (_currentPosition.inSeconds / _videoDuration.inSeconds).clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF55FC27).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // Chapters
                  ..._dummyChapters.map((chapter) {
                    final double positionPercentage = chapter.time.inSeconds / _videoDuration.inSeconds;
                    final double leftPosition = (width * positionPercentage) - 6;

                    Color priorityColor;
                    double size;
                    if (chapter.priority == 'high') {
                      priorityColor = Colors.redAccent;
                      size = 14;
                    } else if (chapter.priority == 'medium') {
                      priorityColor = Colors.orangeAccent;
                      size = 12;
                    } else {
                      priorityColor = Colors.greenAccent;
                      size = 10;
                    }

                    return Positioned(
                      left: leftPosition.clamp(0.0, width - 12),
                      top: (24 - size) / 2,
                      child: Tooltip(
                        message: '${chapter.title} (Priorität: ${chapter.priority.toUpperCase()})',
                        preferBelow: false,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          border: Border.all(color: priorityColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        child: InkWell(
                          onTap: () {
                            player.seek(chapter.time);
                            player.play();
                          },
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: priorityColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: priorityColor.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)
                              ]
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        if (_videoName != null)
          _buildActionButton(Icons.summarize, 'KI Zusammenfassung aktualisieren', true, () {}),
        if (_videoName != null)
          _buildActionButton(Icons.picture_as_pdf, 'Als PDF exportieren', false, _exportPdf),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, bool primary, VoidCallback onPressed) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary ? const Color(0xFF55FC27) : Colors.transparent,
        foregroundColor: primary ? Colors.black : Colors.white,
        side: BorderSide(color: primary ? Colors.transparent : Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAnalysisTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('KERNZUSAMMENFASSUNG', style: TextStyle(color: Color(0xFF55FC27), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        const Text(
          'Das Video vermittelt die fundamentalen Grundlagen des wissenschaftlichen Arbeitens, der Literaturrecherche und des Aufbaus akademischer Arbeiten.\n\n'
          'Kernaussagen:\n'
          '• Wissenschaftlichkeit erfordert Objektivität und Belege.\n'
          '• "Standing on the shoulders of giants": Literaturrecherche ist essenziell.\n'
          '• Reproduzierbarkeit als oberstes Gebot (Detaillierte Methodik).\n'
          '• Primär- vor Sekundärquellen (Stille-Post-Prinzip vermeiden).',
          style: TextStyle(height: 1.6, color: Colors.white70),
        ),
        const SizedBox(height: 24),
        const Text('RELEVANZ FÜR BAUINGENIEURWESEN', style: TextStyle(color: Color(0xFF55FC27), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        const Text(
          '• Methodik: Reproduzierbarkeit ist im Bauwesen entscheidend (z.B. bei Druckfestigkeitsprüfungen).\n'
          '• Quellen: Normen (DIN, Eurocode) statt Wikipedia.',
          style: TextStyle(height: 1.6, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildLearningToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('INTENSIVES LERNEN', style: TextStyle(color: Color(0xFF55FC27), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        _buildFeatureCard(Icons.quiz, 'Quiz Me!', 'Generiert interaktive Quizfragen zum aktuellen Kapitel.'),
        _buildFeatureCard(Icons.library_books, 'Active Recall', 'Erzeugt einen Lückentext aus dem Transkript zum Ausfüllen.'),
        _buildFeatureCard(Icons.flash_on, 'Flashcards Export', 'Erstelle automatische Anki-Karteikarten aus den wichtigsten Begriffen.'),
        _buildFeatureCard(Icons.chat_bubble_outline, 'Grill Me (Mündliche Prüfung)', 'Der KI-Tutor testet dein Wissen im Dialog.'),
      ],
    );
  }

  Widget _buildGamificationTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('DEIN FORTSCHRITT', style: TextStyle(color: Color(0xFF55FC27), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF55FC27).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 48),
              const SizedBox(height: 8),
              const Text('3 Tage Study-Streak!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Bleib dran, um den nächsten Rang zu erreichen.', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: 0.7, backgroundColor: Colors.white12, color: const Color(0xFF55FC27), borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 8),
              const Text('700 / 1000 XP', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF55FC27))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildFeatureCard(Icons.emoji_events, 'Errungenschaften', 'Schalte Badges für intensive Lern-Sessions frei.'),
        _buildFeatureCard(Icons.groups, 'Leaderboard', 'Vergleiche dich mit deinen Kommilitonen.'),
      ],
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF55FC27), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
            onPressed: () {},
          )
        ],
      ),
    );
  }
}
