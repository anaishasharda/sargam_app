import 'dart:math' as math;

/// Helper class for Indian classical music features
class IndianMusicHelper {
  // Sargam (Indian solfege) notes
  static const List<String> sargamNotes = [
    'Sa',
    'Re',
    'Ga',
    'Ma',
    'Pa',
    'Dha',
    'Ni',
  ];

  // Western to Indian note mapping
  static const Map<String, String> westernToSargam = {
    'C': 'Sa',
    'C#': 'Re♭',
    'D': 'Re',
    'D#': 'Ga♭',
    'E': 'Ga',
    'F': 'Ma',
    'F#': 'Ma#',
    'G': 'Pa',
    'G#': 'Dha♭',
    'A': 'Dha',
    'A#': 'Ni♭',
    'B': 'Ni',
  };

  // Common Ragas with their characteristic notes
  static const Map<String, List<String>> commonRagas = {
    'Bilawal': ['Sa', 'Re', 'Ga', 'Ma', 'Pa', 'Dha', 'Ni'],
    'Kafi': ['Sa', 'Re', 'Ga♭', 'Ma', 'Pa', 'Dha', 'Ni♭'],
    'Bhairav': ['Sa', 'Re♭', 'Ga', 'Ma', 'Pa', 'Dha♭', 'Ni'],
    'Kalyan': ['Sa', 'Re', 'Ga', 'Ma#', 'Pa', 'Dha', 'Ni'],
    'Khamaj': ['Sa', 'Re', 'Ga', 'Ma', 'Pa', 'Dha', 'Ni♭'],
    'Asavari': ['Sa', 'Re', 'Ga♭', 'Ma', 'Pa', 'Dha♭', 'Ni♭'],
    'Bhairavi': ['Sa', 'Re♭', 'Ga♭', 'Ma', 'Pa', 'Dha♭', 'Ni♭'],
    'Marwa': ['Sa', 'Re♭', 'Ga', 'Ma#', 'Pa', 'Dha', 'Ni'],
    'Poorvi': ['Sa', 'Re♭', 'Ga', 'Ma#', 'Pa', 'Dha♭', 'Ni'],
    'Todi': ['Sa', 'Re♭', 'Ga♭', 'Ma#', 'Pa', 'Dha♭', 'Ni'],
  };

  // Common Taals (rhythmic patterns)
  static const Map<String, List<int>> commonTaals = {
    'Teentaal': [4, 4, 4, 4], // 16 beats
    'Ektaal': [2, 2, 2, 2, 2, 2], // 12 beats
    'Jhaptaal': [2, 3, 2, 3], // 10 beats
    'Rupak': [3, 2, 2], // 7 beats
    'Dadra': [3, 3], // 6 beats
    'Keherwa': [4, 4], // 8 beats
    'Bhajani': [4, 4], // 8 beats (different accents than Keherwa)
    'Dipchandi': [3, 4, 3, 4], // 14 beats
  };

  // Taal tempo classifications
  static const Map<String, Map<String, int>> taalTempos = {
    'Vilambit': {'min': 40, 'max': 80}, // Slow
    'Madhya': {'min': 80, 'max': 120}, // Medium
    'Drut': {'min': 120, 'max': 200}, // Fast
    'Ati Drut': {'min': 200, 'max': 300}, // Very fast
  };

  /// Convert western note to sargam
  static String westernToSargamNote(String westernNote) {
    return westernToSargam[westernNote] ?? westernNote;
  }

  /// Convert frequency to sargam note
  static String frequencyToSargam(
    double frequency, {
    double baseFrequency = 261.63,
  }) {
    if (frequency <= 0) return '';

    // Calculate the note relative to the base (Sa)
    final ratio = frequency / baseFrequency;
    final semitones = (12 * math.log(ratio) / math.log(2)).round();
    final noteIndex = semitones % 12;

    const westernNotes = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    if (noteIndex >= 0 && noteIndex < westernNotes.length) {
      return westernToSargamNote(westernNotes[noteIndex]);
    }

    return '';
  }

  /// Identify raga from notes
  static String identifyRaga(List<String> detectedNotes) {
    if (detectedNotes.isEmpty) return 'Unknown';

    // Convert western notes to sargam
    final sargamNotes = detectedNotes.map(westernToSargamNote).toSet();

    String bestMatch = 'Unknown';
    int maxMatches = 0;

    for (final entry in commonRagas.entries) {
      final ragaNotes = entry.value.toSet();
      final matches = sargamNotes.intersection(ragaNotes).length;

      if (matches > maxMatches) {
        maxMatches = matches;
        bestMatch = entry.key;
      }
    }

    return maxMatches >= 3 ? bestMatch : 'Unknown';
  }

  /// Identify taal from rhythm pattern
  static String identifyTaal(List<double> rhythmPattern, double tempo) {
    if (rhythmPattern.isEmpty) return 'Unknown';

    // Calculate total beats
    final totalDuration = rhythmPattern.reduce((a, b) => a + b);
    final avgBeatDuration = totalDuration / rhythmPattern.length;
    final estimatedBeats = (totalDuration / avgBeatDuration).round();

    // Find matching taal based on beat count
    for (final entry in commonTaals.entries) {
      final taalBeats = entry.value.reduce((a, b) => a + b);
      if ((estimatedBeats - taalBeats).abs() <= 2) {
        // Allow some tolerance
        return entry.key;
      }
    }

    return 'Unknown';
  }

  /// Get tempo classification
  static String classifyTempo(double bpm) {
    for (final entry in taalTempos.entries) {
      final min = entry.value['min']!;
      final max = entry.value['max']!;
      if (bpm >= min && bpm <= max) {
        return entry.key;
      }
    }
    return 'Unknown';
  }

  /// Generate practice suggestions for specific raga
  static List<String> getRagaPracticeSuggestions(String raga) {
    final suggestions = <String>[];

    switch (raga.toLowerCase()) {
      case 'bilawal':
        suggestions.addAll([
          'Practice ascending (Aaroh): Sa Re Ga Ma Pa Dha Ni Sa',
          'Practice descending (Avroh): Sa Ni Dha Pa Ma Ga Re Sa',
          'Focus on clear transitions between all natural notes',
        ]);
        break;
      case 'kafi':
        suggestions.addAll([
          'Emphasize the flat Ga and flat Ni characteristic of Kafi',
          'Practice meend (gliding) from Ga♭ to Ma',
          'Work on the emotional expression typical of Kafi',
        ]);
        break;
      case 'bhairav':
        suggestions.addAll([
          'Focus on the flat Re and flat Dha',
          'Practice the distinctive Bhairav phrases',
          'Emphasize the serious, devotional mood',
        ]);
        break;
      case 'kalyan':
        suggestions.addAll([
          'Highlight the sharp Ma (Ma#) characteristic',
          'Practice smooth transitions around Ma#',
          'Maintain the bright, uplifting mood of Kalyan',
        ]);
        break;
      default:
        suggestions.addAll([
          'Practice the characteristic notes of this raga',
          'Focus on proper intonation and note transitions',
          'Work on expressing the raga\'s unique mood',
        ]);
    }

    return suggestions;
  }

  /// Generate taal practice suggestions
  static List<String> getTaalPracticeSuggestions(String taal) {
    final suggestions = <String>[];

    switch (taal.toLowerCase()) {
      case 'teentaal':
        suggestions.addAll([
          'Practice the 16-beat cycle: 4+4+4+4',
          'Emphasize beats 1, 5, 9, and 13 (Sam and Taali)',
          'Practice clapping on beats 1, 5, and 13, wave on beat 9',
        ]);
        break;
      case 'ektaal':
        suggestions.addAll([
          'Master the 12-beat cycle: 2+2+2+2+2+2',
          'Focus on the unique accent pattern of Ektaal',
          'Practice with proper hand gestures (Taali and Khali)',
        ]);
        break;
      case 'jhaptaal':
        suggestions.addAll([
          'Practice the 10-beat cycle: 2+3+2+3',
          'Emphasize the asymmetrical pattern',
          'Work on smooth transitions between different beat groups',
        ]);
        break;
      default:
        suggestions.addAll([
          'Practice maintaining steady tempo throughout the cycle',
          'Focus on proper accent placement',
          'Use a metronome or tabla for reference',
        ]);
    }

    return suggestions;
  }

  /// Calculate raga accuracy based on note adherence
  static double calculateRagaAccuracy(
    String expectedRaga,
    List<String> detectedNotes,
  ) {
    if (!commonRagas.containsKey(expectedRaga)) return 0.0;

    final ragaNotes = commonRagas[expectedRaga]!.toSet();
    final sargamDetected = detectedNotes.map(westernToSargamNote).toSet();

    // Calculate how many detected notes belong to the raga
    final correctNotes = sargamDetected.intersection(ragaNotes).length;
    final totalDetected = sargamDetected.length;

    if (totalDetected == 0) return 0.0;

    // Calculate accuracy as percentage of correct notes
    final accuracy = (correctNotes / totalDetected) * 100.0;

    // Bonus for hitting key characteristic notes
    final characteristicNotes = _getCharacteristicNotes(expectedRaga);
    final hitCharacteristic = sargamDetected
        .intersection(characteristicNotes.toSet())
        .length;
    final bonus = (hitCharacteristic / characteristicNotes.length) * 20.0;

    return math.min(100.0, accuracy + bonus);
  }

  /// Get characteristic notes for a raga (most important notes)
  static List<String> _getCharacteristicNotes(String raga) {
    switch (raga.toLowerCase()) {
      case 'bilawal':
        return ['Sa', 'Ga', 'Pa'];
      case 'kafi':
        return ['Sa', 'Ga♭', 'Ni♭'];
      case 'bhairav':
        return ['Sa', 'Re♭', 'Dha♭'];
      case 'kalyan':
        return ['Sa', 'Ma#', 'Ni'];
      case 'khamaj':
        return ['Sa', 'Ga', 'Ni♭'];
      case 'asavari':
        return ['Sa', 'Ga♭', 'Dha♭'];
      case 'bhairavi':
        return ['Sa', 'Re♭', 'Ga♭', 'Dha♭', 'Ni♭'];
      case 'marwa':
        return ['Sa', 'Re♭', 'Ma#'];
      case 'poorvi':
        return ['Sa', 'Re♭', 'Ma#', 'Dha♭'];
      case 'todi':
        return ['Sa', 'Re♭', 'Ga♭', 'Ma#', 'Dha♭'];
      default:
        return ['Sa', 'Pa']; // Default to Sa and Pa
    }
  }

  /// Calculate taal accuracy based on rhythm adherence
  static double calculateTaalAccuracy(
    String expectedTaal,
    List<double> detectedRhythm,
    double tempo,
  ) {
    if (!commonTaals.containsKey(expectedTaal) || detectedRhythm.isEmpty) {
      return 0.0;
    }

    final expectedPattern = commonTaals[expectedTaal]!;
    final expectedBeats = expectedPattern.reduce((a, b) => a + b);

    // Normalize the detected rhythm to match expected beat count
    final normalizedRhythm = _normalizeRhythm(detectedRhythm, expectedBeats);

    // Calculate pattern similarity
    final patternAccuracy = _calculatePatternSimilarity(
      expectedPattern,
      normalizedRhythm,
    );

    // Calculate tempo consistency
    final tempoAccuracy = _calculateTempoConsistency(detectedRhythm);

    // Combined accuracy
    return (patternAccuracy * 0.7 + tempoAccuracy * 0.3);
  }

  static List<double> _normalizeRhythm(List<double> rhythm, int targetBeats) {
    if (rhythm.isEmpty) return [];

    final totalDuration = rhythm.reduce((a, b) => a + b);
    final beatDuration = totalDuration / targetBeats;

    // Group rhythm intervals into beats
    final normalized = <double>[];
    double currentSum = 0.0;
    int beatIndex = 0;

    for (final interval in rhythm) {
      currentSum += interval;
      if (currentSum >= beatDuration || beatIndex == rhythm.length - 1) {
        normalized.add(currentSum);
        currentSum = 0.0;
        beatIndex++;
      }
    }

    return normalized;
  }

  static double _calculatePatternSimilarity(
    List<int> expected,
    List<double> detected,
  ) {
    if (expected.isEmpty || detected.isEmpty) return 0.0;

    final minLength = math.min(expected.length, detected.length);
    double similarity = 0.0;

    for (int i = 0; i < minLength; i++) {
      final expectedRatio = expected[i] / expected.reduce((a, b) => a + b);
      final detectedRatio = detected[i] / detected.reduce((a, b) => a + b);
      similarity += 1.0 - (expectedRatio - detectedRatio).abs();
    }

    return (similarity / minLength) * 100.0;
  }

  static double _calculateTempoConsistency(List<double> rhythm) {
    if (rhythm.length < 2) return 100.0;

    final mean = rhythm.reduce((a, b) => a + b) / rhythm.length;
    double variance = 0.0;

    for (final interval in rhythm) {
      variance += (interval - mean) * (interval - mean);
    }

    variance /= rhythm.length;
    final standardDeviation = math.sqrt(variance);

    // Lower standard deviation means higher consistency
    final consistency = math.max(
      0.0,
      100.0 - (standardDeviation / mean) * 100.0,
    );
    return consistency;
  }

  /// Get learning path suggestions for a student
  static List<String> getLearningPathSuggestions(
    double overallAccuracy,
    String currentRaga,
    String currentTaal,
  ) {
    final suggestions = <String>[];

    if (overallAccuracy < 50) {
      suggestions.addAll([
        'Start with basic sargam practice (Sa Re Ga Ma Pa Dha Ni Sa)',
        'Practice with a tanpura for pitch reference',
        'Focus on breath control and voice stability',
        'Begin with simple ragas like Bilawal or Kafi',
      ]);
    } else if (overallAccuracy < 70) {
      suggestions.addAll([
        'Work on more complex ragas with characteristic phrases',
        'Practice alankar (vocal exercises) daily',
        'Introduce meend (gliding) and gamaka (ornamentation)',
        'Start learning basic taal patterns',
      ]);
    } else if (overallAccuracy < 85) {
      suggestions.addAll([
        'Explore advanced ragas with complex note patterns',
        'Practice different taal variations and speeds',
        'Work on improvisation within raga rules',
        'Study the emotional expression (rasa) of ragas',
      ]);
    } else {
      suggestions.addAll([
        'Master rare and complex ragas',
        'Practice advanced taal patterns and compositions',
        'Focus on artistic expression and creativity',
        'Consider learning different gharana styles',
      ]);
    }

    return suggestions;
  }
}
