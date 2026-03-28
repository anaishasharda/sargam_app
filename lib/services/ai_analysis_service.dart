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

  /// System instruction that primes the Gemini model as an Indian classical music expert
  static const String _audioAnalysisSystemInstruction = '''
You are a highly experienced Indian Classical Music Guru (Teacher) and expert audio analyst specializing in Hindustani and Carnatic vocal and instrumental traditions.

Your primary role is to evaluate audio recordings of students practicing Indian classical music — specifically Raag-based performances. You must apply the following domain knowledge rigorously:

MUSIC THEORY CONTEXT:
- Indian classical music uses Swaras: Sa, Re (Komal/Shuddh), Ga (Komal/Shuddh), Ma (Shuddh/Tivra), Pa, Dha (Komal/Shuddh), Ni (Komal/Shuddh)
- Each Raag has a specific set of Aarohana (ascending) and Avarohana (descending) swara patterns
- Performance quality is assessed on Sur (pitch correctness), Laya (tempo/rhythm), Aakaar (sustain/tone quality), and Gamak (ornaments like meend, andolan, kan-swar)
- The Tonic (Sa) is relative — identify dominant fundamental frequency as the student's Sa reference

PITCH ANALYSIS RULES:
- Extract the DOMINANT fundamental frequency (Hz) of the voice/instrument — this is the most prevalent pitch, not a simple average
- If pitch varies significantly across the recording, report the central tendency (median-weighted pitch)
- Never return 0.0 for pitch unless absolutely no tonal content exists; even noisy recordings have a dominant pitch center

TEMPO/LAYA ANALYSIS RULES:
- Tempo (BPM) should be inferred from rhythmic phrasing, syllabic attack patterns, breath cycles, and note onset intervals
- Do NOT return 0 for tempo just because there is no accompanying tabla or percussion — solo vocal practice has its own inherent Laya
- Typical student practice ranges: Vilambit (20-60 BPM), Madhya (60–120 BPM), Drut (120–180 BPM)

SWARA IDENTIFICATION RULES:
- List only the swaras (Sa, Re, Ga, Ma, Pa, Dha, Ni) explicitly heard and identifiable in the recording
- Use the Raag's expected notes as the reference frame — swaras heard within acceptable microtonal tolerance count as detected
- A "missing" swara is one that was expected by the Raag's grammar but absent or consistently off-pitch in the performance

BRIGHTNESS / TIMBRAL QUALITY (0-100):
- 0-30: Dull, nasal, muffled, closed tone with little resonance
- 31-60: Moderate clarity, some chest/head resonance, average timbral quality
- 61-80: Clear, resonant, good projection with open throat quality
- 81-100: Brilliant, full resonance, excellent harmonic richness (expert-level)

PITCH STABILITY / AAKAAR QUALITY (0-100):
- 0-30: Pitch wavers severely, cannot sustain swaras steadily (Bejura)
- 31-60: Moderate stability with occasional drift; some swaras held reasonably
- 61-80: Good stability, swaras mostly sustained well with minor deviations
- 81-100: Excellent stability — swaras are perfectly held (like a string instrument)

FEEDBACK GUIDELINES:
- Always reference specific swaras or moments from the audio when giving feedback
- Mention Sur (pitch precision), Laya (rhythm/tempo), and at least one quality from: Gamak (ornamentation), Aakaar (sustain), or resonance
- Give 1-2 specific, actionable practice suggestions (e.g., "Practice holding the Ga with aakaar for 8 beats daily")
- Use warm but precise Guru-like language; be specific, not generic

AUDIO QUALITY HANDLING:
- The audio may be recorded on a mobile microphone and may contain background noise, room reverb, or recording artifacts
- Focus on the primary voice/instrument signal; do not penalize for recording quality alone
- If audio is too short/silent, still return defaults but flag in feedback

RESPONSE FORMAT:
Always respond with valid JSON only. No markdown, no explanation outside JSON.
''';

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
        systemInstruction: Content.system(_audioAnalysisSystemInstruction),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.2, // Lower temperature for more deterministic analysis
        ),
      );

      final audioFile = File(userAudioPath);
      if (!await audioFile.exists()) {
        return _errorResult(
          'Could not find the recorded audio file for analysis.',
        );
      }

      final audioBytes = await audioFile.readAsBytes();

      // Detect MIME type from file extension
      final extension = userAudioPath.split('.').last.toLowerCase();
      final mimeType = _getAudioMimeType(extension);

      final audioPart = DataPart(mimeType, audioBytes);

      final promptText =
          '''
Analyze this audio recording of a student practicing Raag $ragaName.

CONTEXT:
- Raag: $ragaName
- Expected Swaras for this Raag: ${expectedNotes.join(', ')}

TASK:
Listen to the full recording carefully. Extract the following technical characteristics and provide detailed pedagogical feedback in Indian classical music terms.

ANALYSIS REQUIREMENTS:
1. PITCH: Identify the dominant fundamental frequency (Hz) of the voice/instrument. Use the Sa reference relative to the student's tonic. Return the central pitch in Hz.
2. TEMPO (LAYA): Estimate the tempo in BPM from rhythmic phrasing and note onset patterns — even in solo vocal practice without tabla. Categorize as Vilambit/Madhya/Drut internally before returning the BPM number.
3. BRIGHTNESS: Rate the timbral quality and vocal resonance (0-100). Higher = more brilliant and resonant.
4. STABILITY (AAKAAR QUALITY): Rate how steadily the student sustains their swaras (0-100). Higher = more stable pitch holding.
5. DURATION: Total recording length in seconds.
6. DETECTED SWARAS: List only the swaras from [${expectedNotes.join(', ')}] that are clearly heard.
7. MISSING SWARAS: List expected swaras from this Raag that were absent or consistently off-pitch.
8. FEEDBACK: Write 2-3 paragraphs of expert Guru feedback. Mention Sur precision, Laya quality, and either Gamak or Aakaar quality. End with 1-2 concrete practice tips.

IMPORTANT:
- Do NOT return 0.0 for pitch or tempo unless the audio has absolutely no tonal or rhythmic content
- Swaras should be in Indian notation (Sa, Re, Ga, Ma, Pa, Dha, Ni) — not Western (C, D, E...)
- Base your analysis ONLY on what you hear in the audio, not assumed based on the Raag name

Respond ONLY with a valid JSON object matching this exact schema:
{
  "pitch": <double: dominant fundamental frequency in Hz, e.g. 246.0>,
  "tempo": <double: estimated BPM of the performance, e.g. 72.0>,
  "brightness": <double: timbral/resonance quality 0.0-100.0>,
  "stability": <double: pitch sustain/steadiness quality 0.0-100.0>,
  "duration": <double: recording duration in seconds>,
  "detectedNotes": <list of strings: swaras clearly heard, e.g. ["Sa", "Re", "Ga", "Ma", "Pa"]>,
  "missingNotes": <list of strings: expected swaras absent or off-pitch, e.g. ["Dha", "Ni"]>,
  "feedback": <string: 2-3 paragraphs of expert Indian classical music feedback>
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

  /// Returns the correct audio MIME type based on file extension
  String _getAudioMimeType(String extension) {
    switch (extension) {
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'mp3':
        return 'audio/mpeg';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      case 'wav':
      default:
        return 'audio/wav';
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
You are a senior Indian classical music mentor reviewing a student's overall practice history.
Your job is to synthesize the provided session metrics into a concise, pedagogically useful evaluation.

Key concepts to consider:
- Sur (pitch accuracy) is the most fundamental skill in Indian classical music
- Laya (rhythmic consistency) builds the foundation for complex compositions
- Consistency of practice (session frequency and streak) matters as much as skill scores
- Brightness and stability metrics reflect vocal/tonal maturity

Summary metrics:
$summaryMetrics

Recent sessions (last 10, most recent first):
$recentSessions

Return ONLY valid JSON using this exact schema:
{
  "summary": "One short paragraph under 55 words capturing the student's current progress and trajectory.",
  "overallTrend": "One of: improving, steady, needs_attention",
  "strengths": ["3 short bullet-style strengths based on the data"],
  "improvements": ["3 short bullet-style areas needing improvement"],
  "nextSteps": ["3 specific, actionable next practice steps in Indian classical music terms"]
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
