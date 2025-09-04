import 'package:flutter_tts/flutter_tts.dart';

class TTSAudioService {
  static final TTSAudioService _instance = TTSAudioService._internal();
  factory TTSAudioService() => _instance;
  TTSAudioService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> initialize() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.3); // Slower for musical notes
    await _flutterTts.setVolume(0.8);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
    });
  }

  Future<void> playAaroh(String ragaName) async {
    if (_isPlaying) return;
    
    _isPlaying = true;
    
    // Define the aaroh (ascending scale) for each raga
    String aarohText = _getAarohText(ragaName);
    
    await _flutterTts.speak(aarohText);
  }

  Future<void> playAvroh(String ragaName) async {
    if (_isPlaying) return;
    
    _isPlaying = true;
    
    // Define the avroh (descending scale) for each raga
    String avrohText = _getAvrohText(ragaName);
    
    await _flutterTts.speak(avrohText);
  }

  Future<void> playSwarmalika(String ragaName) async {
    if (_isPlaying) return;
    
    _isPlaying = true;
    
    // Define a simple melody description for each raga
    String swarmalikaText = _getSwarmalikaText(ragaName);
    
    await _flutterTts.speak(swarmalikaText);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isPlaying = false;
  }

  String _getAarohText(String ragaName) {
    switch (ragaName.toLowerCase()) {
      case 'raag yaman':
        return "Raag Yaman Aaroh: Sa Re Ga Ma Pa Dha Ni Sa";
      case 'raag bhoopali':
        return "Raag Bhoopali Aaroh: Sa Re Ga Pa Dha Sa";
      case 'raag bhairav':
        return "Raag Bhairav Aaroh: Sa Re Ga Ma Pa Dha Ni Sa";
      case 'raag des':
        return "Raag Des Aaroh: Sa Re Ma Pa Ni Sa";
      case 'raag bhairavi':
        return "Raag Bhairavi Aaroh: Sa Re Ga Ma Pa Dha Ni Sa";
      case 'raag durga':
        return "Raag Durga Aaroh: Sa Re Ga Ma Pa Dha Sa";
      default:
        return "Aaroh scale for $ragaName";
    }
  }

  String _getAvrohText(String ragaName) {
    switch (ragaName.toLowerCase()) {
      case 'raag yaman':
        return "Raag Yaman Avroh: Sa Ni Dha Pa Ma Ga Re Sa";
      case 'raag bhoopali':
        return "Raag Bhoopali Avroh: Sa Dha Pa Ga Re Sa";
      case 'raag bhairav':
        return "Raag Bhairav Avroh: Sa Ni Dha Pa Ma Ga Re Sa";
      case 'raag des':
        return "Raag Des Avroh: Sa Ni Pa Ma Re Sa";
      case 'raag bhairavi':
        return "Raag Bhairavi Avroh: Sa Ni Dha Pa Ma Ga Re Sa";
      case 'raag durga':
        return "Raag Durga Avroh: Sa Dha Pa Ma Ga Re Sa";
      default:
        return "Avroh scale for $ragaName";
    }
  }

  String _getSwarmalikaText(String ragaName) {
    switch (ragaName.toLowerCase()) {
      case 'raag yaman':
        return "Raag Yaman Swarmalika: A beautiful evening melody with romantic mood";
      case 'raag bhoopali':
        return "Raag Bhoopali Swarmalika: A joyful pentatonic melody";
      case 'raag bhairav':
        return "Raag Bhairav Swarmalika: A serious morning devotional melody";
      case 'raag des':
        return "Raag Des Swarmalika: A sweet romantic melody";
      case 'raag bhairavi':
        return "Raag Bhairavi Swarmalika: A deep emotional morning melody";
      case 'raag durga':
        return "Raag Durga Swarmalika: A powerful pentatonic melody";
      default:
        return "Swarmalika melody for $ragaName";
    }
  }

  Future<void> dispose() async {
    await _flutterTts.stop();
  }
}
