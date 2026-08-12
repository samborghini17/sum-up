import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:async';
import '../services/pdf_export_service.dart';
import '../services/gemini_service.dart';
import '../services/settings_service.dart';

class AnalyzerScreen extends StatefulWidget {
  final SettingsService settingsService;
  const AnalyzerScreen({super.key, required this.settingsService});

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
  bool _isDragging = false;
  List<StreamSubscription> _subscriptions = [];

  // Analysis state
  bool _isAnalyzing = false;
  String _analysisProgress = '';
  AnalysisResult? _analysisResult;

  // Chat state
  final List<Map<String, String>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  bool _isChatLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    _subscriptions.add(player.stream.duration.listen((duration) {
      if (mounted) setState(() => _videoDuration = duration);
    }));
    _subscriptions.add(player.stream.position.listen((position) {
      if (mounted) setState(() => _currentPosition = position);
    }));

    _chatMessages.add({
      'role': 'model',
      'text': 'Hallo! Lade ein Video und starte die KI-Analyse. Danach kannst du mir Fragen zum Inhalt stellen.',
    });
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    player.dispose();
    _tabController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'avi', 'mov', 'webm'],
    );
    if (result != null && result.files.single.path != null) {
      _loadVideo(result.files.single.path!, result.files.single.name);
    }
  }

  void _loadVideo(String path, String name) {
    setState(() {
      _videoPath = path;
      _videoName = name;
      _analysisResult = null; // Reset analysis for new video
    });
    player.open(Media(path));
  }

  Future<void> _startAnalysis() async {
    if (_videoPath == null) return;

    if (!widget.settingsService.hasApiKey) {
      _showSnackBar('Bitte erst den Gemini API Key in den Einstellungen hinterlegen!', isError: true);
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 'Video wird hochgeladen und analysiert...\nDies kann bei großen Videos einige Minuten dauern.';
    });

    try {
      final gemini = GeminiService(widget.settingsService.geminiApiKey);
      final result = await gemini.analyzeVideo(_videoPath!);

      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });
      _tabController.animateTo(0); // Switch to analysis tab
      _showSnackBar('Analyse erfolgreich abgeschlossen! ${result.chapters.length} Kapitel erkannt.');
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _analysisProgress = '';
      });
      _showSnackBar('Fehler bei der Analyse: $e', isError: true);
    }
  }

  Future<void> _exportPdf() async {
    if (_videoName == null || _analysisResult == null) {
      _showSnackBar('Bitte erst ein Video laden und analysieren.', isError: true);
      return;
    }

    try {
      _showSnackBar('Generiere PDF...');
      final path = await PdfExportService.generateAndSavePdf(
        videoName: _videoName!,
        summary: _analysisResult!.summary,
        timestamps: _analysisResult!.chapters.map((c) {
          final mins = c.time.inMinutes.toString().padLeft(2, '0');
          final secs = (c.time.inSeconds % 60).toString().padLeft(2, '0');
          return {'time': '$mins:$secs', 'title': '${c.title} [${c.priority.toUpperCase()}]'};
        }).toList(),
      );
      _showSnackBar('PDF exportiert: $path');
    } catch (e) {
      _showSnackBar('PDF Export Fehler: $e', isError: true);
    }
  }

  Future<void> _sendChatMessage() async {
    final msg = _chatController.text.trim();
    if (msg.isEmpty) return;

    if (!widget.settingsService.hasApiKey) {
      _showSnackBar('Bitte erst den API Key hinterlegen!', isError: true);
      return;
    }

    setState(() {
      _chatMessages.add({'role': 'user', 'text': msg});
      _chatController.clear();
      _isChatLoading = true;
    });

    try {
      final gemini = GeminiService(widget.settingsService.geminiApiKey);
      // If we have an analysis, the chat method will use it as context
      if (_analysisResult != null) {
        // We need to pass the analysis context - the service stores it internally
        // So we create a new service instance... let's improve this.
        // For now, we pass the context through the message itself.
      }
      final reply = await gemini.chat(
        _analysisResult != null
            ? 'Analyse-Kontext:\n${_analysisResult!.summary}\n\nFrage: $msg'
            : msg,
      );
      setState(() {
        _chatMessages.add({'role': 'model', 'text': reply});
      });
    } catch (e) {
      setState(() {
        _chatMessages.add({'role': 'model', 'text': 'Fehler: $e'});
      });
    } finally {
      setState(() => _isChatLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : const Color(0xFF55FC27),
      duration: Duration(seconds: isError ? 5 : 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1024;
    final bool isTablet = MediaQuery.of(context).size.width >= 600 && !isDesktop;

    return DropTarget(
      onDragDone: (detail) {
        if (detail.files.isNotEmpty) {
          final file = detail.files.first;
          final ext = file.path.split('.').last.toLowerCase();
          if (['mp4', 'mkv', 'avi', 'mov', 'webm'].contains(ext)) {
            _loadVideo(file.path, file.name);
          } else {
            _showSnackBar('Nur Video-Dateien (.mp4, .mkv, .avi, .mov, .webm)', isError: true);
          }
        }
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: Container(
        decoration: BoxDecoration(
          border: _isDragging ? Border.all(color: const Color(0xFF55FC27), width: 4) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Content (Video Player & Timeline)
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildVideoPlayer(),
                    const SizedBox(height: 16),
                    if (_videoPath != null && _analysisResult != null && _analysisResult!.chapters.isNotEmpty)
                      _buildInteractiveTimeline(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
            // Right Panel (Tabs)
            if (isDesktop || isTablet)
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
                        isScrollable: true,
                        tabs: const [
                          Tab(text: 'Analyse'),
                          Tab(text: 'KI Chat'),
                          Tab(text: 'Lern-Tools'),
                          Tab(text: 'Info'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildAnalysisTab(),
                            _buildAIChatTab(),
                            _buildLearningToolsTab(),
                            _buildInfoTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
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
            label: const Text('Video auswählen oder hierher ziehen (Drag & Drop)'),
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
          border: Border.all(color: const Color(0xFF55FC27).withOpacity(_isDragging ? 1.0 : 0.3), width: _isDragging ? 3 : 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, spreadRadius: 5)
          ],
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
                    Text(
                      _isDragging ? '...lass das Video hier los!' : 'Wähle ein Video zum Abspielen aus',
                      style: TextStyle(
                        color: _isDragging ? const Color(0xFF55FC27) : Colors.white54,
                        fontWeight: _isDragging ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInteractiveTimeline() {
    if (_videoDuration.inSeconds == 0) return const SizedBox.shrink();
    final chapters = _analysisResult!.chapters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KAPITEL & THEMEN (Priorisiert nach Prüfungsrelevanz)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54),
        ),
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
                  // Chapter markers
                  ...chapters.map((chapter) {
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
                              ],
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
        const SizedBox(height: 12),
        // Chapter list below timeline
        ...chapters.map((ch) {
          final mins = ch.time.inMinutes.toString().padLeft(2, '0');
          final secs = (ch.time.inSeconds % 60).toString().padLeft(2, '0');
          Color dotColor;
          if (ch.priority == 'high') {
            dotColor = Colors.redAccent;
          } else if (ch.priority == 'medium') {
            dotColor = Colors.orangeAccent;
          } else {
            dotColor = Colors.greenAccent;
          }
          return InkWell(
            onTap: () {
              player.seek(ch.time);
              player.play();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Text('$mins:$secs', style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF55FC27), fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(ch.title, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        if (_videoName != null)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF55FC27),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _isAnalyzing ? null : _startAnalysis,
            icon: _isAnalyzing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.auto_awesome),
            label: Text(
              _isAnalyzing ? 'Analysiere...' : (_analysisResult != null ? 'Erneut analysieren' : 'KI ANALYSE STARTEN'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        if (_analysisResult != null)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Als PDF exportieren', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  // ─── TABS ─────────────────────────────────────────────────

  Widget _buildAnalysisTab() {
    if (_isAnalyzing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF55FC27)),
            const SizedBox(height: 24),
            Text(_analysisProgress, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (_analysisResult == null) {
      return const Center(
        child: Text(
          'Lade ein Video und klicke auf "KI ANALYSE STARTEN"\num die Auswertung zu generieren.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('KI ANALYSE', style: TextStyle(color: Color(0xFF55FC27), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        SelectableText(
          _analysisResult!.summary,
          style: const TextStyle(height: 1.6, color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildAIChatTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final msg = _chatMessages[index];
              final isUser = msg['role'] == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  constraints: const BoxConstraints(maxWidth: 350),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF55FC27).withOpacity(0.15) : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isUser ? const Color(0xFF55FC27).withOpacity(0.5) : Colors.white12),
                  ),
                  child: SelectableText(
                    msg['text']!,
                    style: TextStyle(height: 1.5, color: isUser ? Colors.white : Colors.white70, fontSize: 13),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isChatLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(color: Color(0xFF55FC27)),
          ),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12))),
          child: TextField(
            controller: _chatController,
            onSubmitted: (_) => _sendChatMessage(),
            decoration: InputDecoration(
              hintText: 'Frag die KI zum Video...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF55FC27)),
                onPressed: _sendChatMessage,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLearningToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('LERN-TOOLS', style: TextStyle(color: Color(0xFF55FC27), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        _buildFeatureCard(Icons.quiz, 'Quiz Me!', 'Generiert interaktive Quizfragen zum aktuellen Video.'),
        _buildFeatureCard(Icons.library_books, 'Active Recall', 'Erzeugt einen Lückentext aus der Zusammenfassung.'),
        _buildFeatureCard(Icons.flash_on, 'Flashcards Export', 'Erstelle automatische Anki-Karteikarten (CSV).'),
        _buildFeatureCard(Icons.chat_bubble_outline, 'Grill Me (Mündl. Prüfung)', 'Der KI-Tutor testet dein Wissen im Dialog.'),
        _buildFeatureCard(Icons.emoji_events, 'Gamification & Streaks', 'XP-System und Study-Streaks (Demnächst).'),
      ],
    );
  }

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('WIE FUNKTIONIERT DIESE APP?', style: TextStyle(color: Color(0xFF55FC27), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        const Text(
          'Diese App nutzt dasselbe Prinzip wie gemini.js (github.com/msveshnikov/allchat):\n',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF55FC27).withOpacity(0.3)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1. VIDEO EINLESEN', style: TextStyle(color: Color(0xFF55FC27), fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Die Videodatei wird lokal von deiner Festplatte gelesen und in einen Base64-String umgewandelt (binäre Daten → Text).', style: TextStyle(color: Colors.white70, height: 1.5)),
              SizedBox(height: 16),
              Text('2. AN GEMINI API SENDEN', style: TextStyle(color: Color(0xFF55FC27), fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Der Base64-String wird zusammen mit einem Analyse-Prompt per HTTPS an die Google Gemini API gesendet. Bei großen Videos (>20MB) wird die File API verwendet, die das Video in Chunks hochlädt.', style: TextStyle(color: Colors.white70, height: 1.5)),
              SizedBox(height: 16),
              Text('3. MULTIMODALE KI-ANALYSE', style: TextStyle(color: Color(0xFF55FC27), fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Gemini 2.0 Flash analysiert das Video multimodal: Es \"sieht\" die Bilder/Folien UND \"hört\" den gesprochenen Text gleichzeitig. Das Modell erstellt daraus eine strukturierte Zusammenfassung mit Timecodes und Prüfungsrelevanz.', style: TextStyle(color: Colors.white70, height: 1.5)),
              SizedBox(height: 16),
              Text('4. ERGEBNIS PARSEN', style: TextStyle(color: Color(0xFF55FC27), fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Die App parst die Gemini-Antwort: Der Text wird als Zusammenfassung angezeigt, die JSON-Kapitel werden auf der Timeline als farbige Marker dargestellt (Rot = prüfungsrelevant, Gelb = wichtig, Grün = Kontext).', style: TextStyle(color: Colors.white70, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('// gemini.js – Original-Code (vereinfacht)', style: TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11)),
              SizedBox(height: 8),
              SelectableText(
                'async function getTextGemini(prompt, imageBase64, fileType) {\n'
                '  const parts = [];\n'
                '  if (fileType === "mp4") {\n'
                '    parts.push({\n'
                '      inlineData: {\n'
                '        mimeType: "video/mp4",\n'
                '        data: imageBase64,  // ← Base64-Video\n'
                '      },\n'
                '    });\n'
                '  }\n'
                '  parts.push({ text: prompt });\n'
                '  const result = await model.generateContent({\n'
                '    contents: [{ parts }],\n'
                '  });\n'
                '  return result.response.text();\n'
                '}',
                style: TextStyle(color: Color(0xFF55FC27), fontFamily: 'monospace', fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('IMPRESSUM', style: TextStyle(color: Color(0xFF55FC27), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        const Text(
          'KIO Video Analyzer\n'
          'Ein KI-gestütztes Videoanalyse-Tool für Studierende\n\n'
          'Entwickelt von / für:\n'
          'KREATIV INSTITUT.OWL\n\n'
          'Technologie:\n'
          '• Flutter (Desktop & Mobile)\n'
          '• Google Gemini 2.0 Flash API\n'
          '• MediaKit Video Player\n'
          '• Basierend auf dem gemini.js-Pattern von AllChat\n'
          '  (github.com/msveshnikov/allchat)\n\n'
          'Kontakt:\n'
          'kreativ.institute',
          style: TextStyle(color: Colors.white70, height: 1.6),
        ),
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
          const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
        ],
      ),
    );
  }
}
