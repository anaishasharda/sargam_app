import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIAnalysisService {
  // TODO: Replace this with your actual Gemini API Key
  static const String _apiKey = 'YOUR_GEMINI_API_KEY_HERE';

  static final AIAnalysisService _instance = AIAnalysisService._internal();

  factory AIAnalysisService() {
    return _instance;
  }

  AIAnalysisService._internal();

  Future<String> getAIFeedback({
    required String userAudioPath,
    required List<String> expectedNotes,
    required String ragaName,
  }) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE' || _apiKey.isEmpty) {
      return 'Please set your Gemini API key in lib/services/ai_analysis_service.dart to get AI feedback on your performance.';
    }

    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);

      final audioFile = File(userAudioPath);
      if (!await audioFile.exists()) {
        return 'Could not find the recorded audio file for analysis.';
      }

      final audioBytes = await audioFile.readAsBytes();
      final audioPart = DataPart('audio/wav', audioBytes);

      final promptText =
          '''
You are an expert Indian Classical Music teacher (Guru) analyzing a student's singing of a Raag using direct audio.
The student was practicing Raag $ragaName, which uses the expected notes: ${expectedNotes.join(', ')}.

Listen to the attached audio recording of the student's singing.
Provide concise, constructive, and encouraging feedback in 2-3 short paragraphs.
1. Analyze their pitch, rhythm, and stability. Mention if they hit the correct reference notes.
2. Point out specific areas for improvement (e.g., if their pitch is wavering, or if they missed or incorrectly sang any of the expected notes).
3. Keep it encouraging and use terms accessible to a beginner or intermediate music student.
''';

      final content = [
        Content.multi([TextPart(promptText), audioPart]),
      ];

      final response = await model.generateContent(content);

      return response.text ??
          'I could not generate feedback at this time, please try again.';
    } catch (e) {
      print('Error getting AI feedback is: \$e');
      return 'There was an error generating AI feedback. The audio file might be too large or there might be an API connection issue.';
    }
  }
}
