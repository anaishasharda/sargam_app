import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ai_feedback_result.dart'; // Add import for the new model

class PracticeProgressAnalysis {
  final String summary;
  final String overallTrend;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> nextSteps;

  const PracticeProgressAnalysis({
    required this.summary,
    required this.overallTrend,
    required this.strengths,
    required this.improvements,
    required this.nextSteps,
  });

  factory PracticeProgressAnalysis.fallback(String summary) {
    return PracticeProgressAnalysis(
      summary: summary,
      overallTrend: 'Insufficient AI data',
      strengths: const [
        'Practice history is available and ready for analysis.',
      ],
      improvements: const [
        'Add a valid Gemini API key in Firestore config/ai_settings.',
      ],
      nextSteps: const [
        'Keep logging practice sessions with pitch and timing metrics.',
      ],
    );
  }

  factory PracticeProgressAnalysis.fromJson(String json) {
    return PracticeProgressAnalysis.fromMap(
      Map<String, dynamic>.from(jsonDecode(json) as Map),
    );
  }

  factory PracticeProgressAnalysis.fromMap(Map<String, dynamic> data) {
    List<String> stringList(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      return [];
    }

    return PracticeProgressAnalysis(
      summary: data['summary']?.toString() ?? 'No summary available.',
      overallTrend: data['overallTrend']?.toString() ?? 'Unknown',
      strengths: stringList(data['strengths']),
      improvements: stringList(data['improvements']),
      nextSteps: stringList(data['nextSteps']),
    );
  }
}

class AIAnalysisService {
  // TODO: Replace this with your actual Gemini API Key
  static const String _apiKey = 'jdksnfksdnfkjdnskn';

  static final AIAnalysisService _instance = AIAnalysisService._internal();

  factory AIAnalysisService() {
    return _instance;
  }

  AIAnalysisService._internal();

  Future<({String apiKey, String modelName})> _loadAiConfig() async {
    String apiKey = _apiKey;
    String modelName = 'gemini-2.5-flash';

    try {
      final configDoc = await FirebaseFirestore.instance
          .collection('config')
          .doc('ai_settings')
          .get();
      if (configDoc.exists) {
        final data = configDoc.data();
        if (data != null) {
          apiKey = data['api_key'] ?? apiKey;
          modelName = data['model_name'] ?? modelName;
        }
      }
    } catch (e) {
      print('Error fetching AI config from Firestore: $e');
    }

    return (apiKey: apiKey, modelName: modelName);
  }

  Future<GenerativeModel?> _buildJsonModel() async {
    final config = await _loadAiConfig();
    if (config.apiKey == 'YOUR_GEMINI_API_KEY_HERE' || config.apiKey.isEmpty) {
      return null;
    }

    return GenerativeModel(
      model: config.modelName,
      apiKey: config.apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
  }

  /// Create a default "error" fallback result
  AIFeedbackResult _errorResult(String message) {
    return AIFeedbackResult(
      pitch: 0.0,
      tempo: 0.0,
      brightness: 0.0,
      stability: 0.0,
      duration: 0.0,
      detectedNotes: [],
      missingNotes: [],
      feedback: message,
    );
  }

  Future<AIFeedbackResult> getAIFeedback({
    required String userAudioPath,
    required List<String> expectedNotes,
    required String ragaName,
  }) async {
    final config = await _loadAiConfig();
    final apiKey = config.apiKey;
    final modelName = config.modelName;

    if (apiKey == 'YOUR_GEMINI_API_KEY_HERE' || apiKey.isEmpty) {
      return _errorResult(
        'Please set your Gemini API key in the Firestore config (config/ai_settings) to get AI feedback on your performance.',
      );
    }

    try {
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      final audioFile = File(userAudioPath);
      if (!await audioFile.exists()) {
        return _errorResult(
          'Could not find the recorded audio file for analysis.',
        );
      }

      final audioBytes = await audioFile.readAsBytes();
      final audioPart = DataPart('audio/wav', audioBytes);

      final promptText =
          '''
You are an expert Indian Classical Music teacher (Guru) with deep knowledge of audio analysis. You are analyzing a student's singing of a Raag.
The student was practicing Raag $ragaName, which uses the expected notes: ${expectedNotes.join(', ')}.

Listen carefully to the attached audio recording. You need to extract specific technical audio characteristics and provide pedagogical feedback based on Indian Classical Music principles (such as Sur, Laya, and vocal timbre).

You MUST respond ONLY with a valid JSON object matching this exact schema:
{
  "pitch": double (Calculate the overall average pitch in Hz. e.g. 220.0),
  "tempo": double (Calculate the tempo in BPM representing the Laya of the performance, e.g. 80.0. Do not return 0 unless there is no rhythmic element.),
  "brightness": double (Evaluate the vocal brightness, resonance, and timbre quality on a scale of 0.0 to 100.0),
  "stability": double (Evaluate the pitch stability and steadiness of notes (Aakaar/Sustain) on a scale of 0.0 to 100.0),
  "duration": double (audio duration in seconds),
  "detectedNotes": [list of strings representing the specific Swaras identified in the audio, e.g. ["Sa", "Re", "Ga"]],
  "missingNotes": [list of strings representing expected Swaras from $ragaName that the student failed to sing or sang incorrectly],
  "feedback": string (Provide 2-3 paragraphs of expert feedback. Detail their strengths and weaknesses regarding precision of Sur (pitch), steadiness (stability), Laya (tempo/rhythm), and overall resonance (brightness). Give actionable advice for improvement.)
}
''';

      final content = [
        Content.multi([TextPart(promptText), audioPart]),
      ];

      final response = await model.generateContent(content);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        return _errorResult(
          'I could not generate feedback at this time, please try again.',
        );
      }

      return AIFeedbackResult.fromJson(responseText);
    } catch (e) {
      print('Error getting AI feedback is: \$e');
      return _errorResult(
        'There was an error generating AI feedback. The audio file might be too large or there might be an API connection issue.',
      );
    }
  }

  Future<PracticeProgressAnalysis> getPracticeProgressAnalysis({
    required Map<String, dynamic> summaryMetrics,
    required List<Map<String, dynamic>> recentSessions,
  }) async {
    final model = await _buildJsonModel();
    if (model == null) {
      return PracticeProgressAnalysis.fallback(
        'Connect Gemini in Firestore config to unlock detailed progress analysis.',
      );
    }

    try {
      final promptText =
          '''
You are an expert Indian classical music mentor analyzing a student's historical practice progress.
Use the provided summary metrics and recent sessions to produce a very short evaluation and actionable improvement advice.

Summary metrics:
$summaryMetrics

Recent sessions:
$recentSessions

Return ONLY valid JSON using this exact schema:
{
  "summary": "One short paragraph under 55 words that explains the user's current progress.",
  "overallTrend": "One of: improving, steady, needs_attention",
  "strengths": ["3 short bullet-style strengths"],
  "improvements": ["3 short bullet-style improvement areas"],
  "nextSteps": ["3 concrete next practice steps"]
}
''';

      final response = await model.generateContent([Content.text(promptText)]);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        return PracticeProgressAnalysis.fallback(
          'AI analysis is currently unavailable. Your practice metrics are still shown above.',
        );
      }

      final jsonData = _extractJsonMap(responseText);
      return PracticeProgressAnalysis.fromMap(jsonData);
    } catch (e) {
      print('Error getting practice progress analysis: $e');
      return PracticeProgressAnalysis.fallback(
        'AI analysis could not be generated right now. Try again after more practice sessions are logged.',
      );
    }
  }

  Map<String, dynamic> _extractJsonMap(String rawText) {
    final cleaned = rawText.trim();
    return Map<String, dynamic>.from(
      jsonDecode(cleaned) as Map<String, dynamic>,
    );
  }
}
