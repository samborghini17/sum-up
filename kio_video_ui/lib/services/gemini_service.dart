import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Data model for a video chapter identified by Gemini.
class VideoChapter {
  final String title;
  final Duration time;
  final String priority; // 'high', 'medium', 'low'

  VideoChapter(this.title, this.time, this.priority);

  factory VideoChapter.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['time'] as String? ?? '00:00').split(':');
    final minutes = int.tryParse(timeParts[0]) ?? 0;
    final seconds = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
    return VideoChapter(
      json['title'] as String? ?? 'Unbekanntes Kapitel',
      Duration(minutes: minutes, seconds: seconds),
      json['priority'] as String? ?? 'medium',
    );
  }
}

/// Data model for the full analysis result.
class AnalysisResult {
  final String summary;
  final List<VideoChapter> chapters;

  AnalysisResult({required this.summary, required this.chapters});
}

/// Service that communicates with the Google Gemini REST API.
/// This is the Dart equivalent of gemini.js: it reads a video file,
/// encodes it as Base64, and sends it to the Gemini API for multimodal analysis.
class GeminiService {
  final String apiKey;
  String? _lastAnalysisContext; // stores the last analysis for chat context

  GeminiService(this.apiKey);

  /// Analyzes a video file by sending it as base64 to Gemini.
  /// This is exactly what gemini.js does:
  /// 1. Read the file bytes
  /// 2. Base64-encode them
  /// 3. Send as inlineData with mimeType "video/mp4" to Gemini
  /// 4. Parse the structured response
  Future<AnalysisResult> analyzeVideo(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Datei nicht gefunden: $filePath');
    }

    final fileSize = await file.length();
    // Gemini inline data limit is ~20MB for base64 encoded.
    // For larger videos, we'd need the File API, but let's try inline first.
    if (fileSize > 20 * 1024 * 1024) {
      // Use File API upload for large files
      return _analyzeVideoWithFileApi(filePath);
    }

    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);

    final mimeType = _getMimeType(filePath);

    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Data,
                },
              },
              {
                'text': _buildAnalysisPrompt(),
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.4,
          'maxOutputTokens': 8192,
        },
      }),
    );

    return _parseAnalysisResponse(response);
  }

  /// For large files (>20MB), use the Gemini File API to upload first.
  Future<AnalysisResult> _analyzeVideoWithFileApi(String filePath) async {
    final file = File(filePath);
    final fileSize = await file.length();
    final mimeType = _getMimeType(filePath);
    final displayName = filePath.split(Platform.pathSeparator).last;

    // Step 1: Start resumable upload
    final startResponse = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/upload/v1beta/files?key=$apiKey',
      ),
      headers: {
        'X-Goog-Upload-Protocol': 'resumable',
        'X-Goog-Upload-Command': 'start',
        'X-Goog-Upload-Header-Content-Length': fileSize.toString(),
        'X-Goog-Upload-Header-Content-Type': mimeType,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'file': {'display_name': displayName},
      }),
    );

    final uploadUrl = startResponse.headers['x-goog-upload-url'];
    if (uploadUrl == null) {
      throw Exception('Fehler beim Starten des Uploads: ${startResponse.body}');
    }

    // Step 2: Upload file bytes
    final bytes = await file.readAsBytes();
    final uploadResponse = await http.put(
      Uri.parse(uploadUrl),
      headers: {
        'Content-Length': fileSize.toString(),
        'X-Goog-Upload-Offset': '0',
        'X-Goog-Upload-Command': 'upload, finalize',
      },
      body: bytes,
    );

    final uploadResult = jsonDecode(uploadResponse.body);
    final fileUri = uploadResult['file']?['uri'] as String?;
    if (fileUri == null) {
      throw Exception('Upload fehlgeschlagen: ${uploadResponse.body}');
    }

    // Step 3: Wait for file processing
    final fileName = uploadResult['file']['name'] as String;
    String state = uploadResult['file']['state'] as String? ?? 'PROCESSING';
    int attempts = 0;
    while (state == 'PROCESSING' && attempts < 60) {
      await Future.delayed(const Duration(seconds: 3));
      final statusResp = await http.get(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/$fileName?key=$apiKey',
        ),
      );
      final statusResult = jsonDecode(statusResp.body);
      state = statusResult['state'] as String? ?? 'ACTIVE';
      attempts++;
    }

    if (state != 'ACTIVE') {
      throw Exception('Video-Verarbeitung fehlgeschlagen (Status: $state)');
    }

    // Step 4: Generate content using the uploaded file
    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'fileData': {
                  'mimeType': mimeType,
                  'fileUri': fileUri,
                },
              },
              {
                'text': _buildAnalysisPrompt(),
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.4,
          'maxOutputTokens': 8192,
        },
      }),
    );

    return _parseAnalysisResponse(response);
  }

  /// Parse the Gemini API response into an AnalysisResult.
  AnalysisResult _parseAnalysisResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API Fehler (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '';
    _lastAnalysisContext = text;

    // Try to parse chapters from the response
    final chapters = <VideoChapter>[];
    
    // Look for JSON block in the response
    final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(text);
    if (jsonMatch != null) {
      try {
        final jsonStr = jsonMatch.group(1)!;
        final parsed = jsonDecode(jsonStr);
        if (parsed is Map && parsed.containsKey('chapters')) {
          for (final ch in (parsed['chapters'] as List)) {
            chapters.add(VideoChapter.fromJson(ch as Map<String, dynamic>));
          }
        }
      } catch (_) {
        // JSON parsing failed, fall back to text-only
      }
    }

    // Extract the summary text (everything before the JSON block, or the full text)
    String summary;
    if (jsonMatch != null) {
      summary = text.substring(0, jsonMatch.start).trim();
      // Also append anything after the JSON block
      final after = text.substring(jsonMatch.end).trim();
      if (after.isNotEmpty) {
        summary += '\n\n$after';
      }
    } else {
      summary = text;
    }

    return AnalysisResult(summary: summary, chapters: chapters);
  }

  /// Send a follow-up chat message in the context of the last analysis.
  Future<String> chat(String message) async {
    final contextMsg = _lastAnalysisContext != null
        ? 'Kontext der letzten Videoanalyse:\n$_lastAnalysisContext\n\n'
        : '';

    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                    '${contextMsg}Du bist ein akademischer Fachtutor. Der Studierende fragt:\n$message\n\nAntworte präzise und hilfreich auf Deutsch.',
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 4096,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API Fehler: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ??
        'Keine Antwort erhalten.';
  }

  String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'mkv':
        return 'video/x-matroska';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }

  String _buildAnalysisPrompt() {
    return '''Du bist ein akademischer Fachtutor. Analysiere dieses Video vollständig und erstelle eine strukturierte Auswertung.

Antworte IMMER in folgendem Format:

## Kernzusammenfassung
[Fasse die wichtigsten Ergebnisse, Kernaussagen und fachlichen Informationen zusammen.]

## Relevanz für das Studium
[Erkläre, warum dieser Stoff für Studierende relevant ist.]

## Wichtige Konzepte
[Liste die wichtigsten Konzepte und Definitionen auf.]

## Prüfungshinweise
[Welche Aspekte könnten in einer Prüfung abgefragt werden?]

Gib ZUSÄTZLICH am Ende einen JSON-Block mit den wichtigsten Kapiteln/Timecodes aus, in exakt diesem Format:
```json
{
  "chapters": [
    {"time": "MM:SS", "title": "Kapitelname", "priority": "high"},
    {"time": "MM:SS", "title": "Kapitelname", "priority": "medium"},
    {"time": "MM:SS", "title": "Kapitelname", "priority": "low"}
  ]
}
```

Priority-Werte:
- "high" = prüfungsrelevant, komplexes Konzept
- "medium" = wichtig, aber weniger komplex  
- "low" = Kontext/Einführung

Antworte auf Deutsch.''';
  }
}
