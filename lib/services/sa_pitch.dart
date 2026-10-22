import 'dart:math';

/// Sa-relative pitch utilities for the `bhopali-accuracy` branch.
///
/// Implements plan items 1.1 (Sa calibration) and the shared foundation for
/// 1.2 (raga-parameterized swara mapping) and 1.8 (Sa-normalized comparison).
///
/// Design rules this file follows:
/// - Everything is computed in cents relative to the singer's own Sa.
///   Absolute Hz is never compared between singers.
/// - Pure Dart: no Flutter, no Firebase. Storage (users/{uid} fields
///   baseSaHz / saCalibratedAt / saConfidence) is wired separately.
/// - All thresholds are starting hypotheses (see plan 1.5) — tune against
///   labeled recordings.
///
/// Suggested home in the repo: lib/services/sa_pitch.dart

// ---------------------------------------------------------------------------
// Cents conversion
// ---------------------------------------------------------------------------

/// Cents of [freqHz] relative to [saHz].
/// 0 = exactly Sa, +100 = one semitone above Sa, -100 = one below.
double centsFromSa(double freqHz, double saHz) {
  assert(freqHz > 0 && saHz > 0, 'frequencies must be positive');
  return 1200.0 * log(freqHz / saHz) / ln2;
}

/// Frequency in Hz that lies [cents] above [saHz].
double freqFromCents(double saHz, double cents) {
  return (saHz * pow(2.0, cents / 1200.0)).toDouble();
}

// ---------------------------------------------------------------------------
// Sa calibration (plan 1.1): 3 takes, stability gate, agreement gate
// ---------------------------------------------------------------------------

/// Result of analyzing one "hold your Sa" take.
class SaTakeResult {
  /// Median pitch of the take's stable middle portion, in Hz.
  final double medianHz;

  /// Std dev of the take's samples, in cents relative to [medianHz],
  /// computed on octave-folded deviations (see [_foldToOctave]).
  final double stdDevCents;

  const SaTakeResult({required this.medianHz, required this.stdDevCents});

  /// A take counts as usable only if the held note was steady.
  bool get isStable => stdDevCents <= 25.0;
}

/// Analyze one take from its raw YIN pitch samples (Hz).
/// The caller should pass only the middle ~2 seconds (attack skipped);
/// unvoiced/dropout samples (<= 0) are ignored here.
/// Returns null when the take has no voiced samples — the caller treats
/// that as an unusable take ("couldn't hear you"), not a crash.
///
/// Steadiness is measured on octave-folded deviations (see
/// [_foldToOctave]): the pitch tracker intermittently reports a held note
/// an octave off, and those frames must not count as the singer wobbling.
/// (Device evidence, 2026-10-21: on a classical singer's steady held Sa at
/// ~225 Hz, ~40% of frames read an octave off — every take scored
/// stdDev ~600c and was rejected, while the median stayed true.)
SaTakeResult? analyzeSaTake(List<double> pitchSamplesHz) {
  final voiced =
      pitchSamplesHz.where((f) => f > 0).toList(growable: false);
  if (voiced.isEmpty) return null;
  final median = _median(voiced);
  final variance = voiced
          .map((f) => pow(_foldToOctave(centsFromSa(f, median)), 2))
          .reduce((a, b) => a + b) /
      voiced.length;
  return SaTakeResult(
    medianHz: median,
    stdDevCents: sqrt(variance),
  );
}

/// Fold a cents deviation into [-600, 600): deviations an exact octave
/// apart become equal. For steadiness only — a take's level is its
/// (unfolded) median, and the playback confirmation checks it by ear.
double _foldToOctave(double cents) => ((cents + 600) % 1200) - 600;

/// A completed calibration: the student's Sa, agreed across takes.
class SaCalibration {
  /// Agreed Sa in Hz (median of take medians, octave-normalized —
  /// see [calibrateSa]).
  final double saHz;

  /// Worst disagreement among takes, in cents. Lower = more confident.
  final double agreementCents;

  final DateTime calibratedAt;

  const SaCalibration({
    required this.saHz,
    required this.agreementCents,
    required this.calibratedAt,
  });

  /// Simple confidence flag for the teacher summary / drift logic.
  /// 'high' when takes agree tightly, 'ok' otherwise.
  String get confidence => agreementCents <= 15.0 ? 'high' : 'ok';
}

/// Attempt calibration from [takes] (expect 3).
/// Returns null when calibration cannot be trusted:
/// fewer than 3 takes, any take unstable, or takes disagree beyond
/// [agreementBandCents]. The caller retries only the failed part.
///
/// Agreement is judged on pitch class: the tracker sometimes locks a
/// whole take an octave off (device evidence, 2026-10-21: one of three
/// identical 233 Hz sine takes read 116.67 Hz), so every median is first
/// folded into the anchor (median-of-medians) octave and the proposal is
/// made in that octave. The student's playback confirmation is the final
/// check of the octave itself.
SaCalibration? calibrateSa(
  List<SaTakeResult> takes, {
  double agreementBandCents = 30.0,
}) {
  if (takes.length < 3) return null;
  if (takes.any((t) => !t.isStable)) return null;
  final medians = takes.map((t) => t.medianHz).toList(growable: false);
  final anchor = _median(medians);
  final folded = medians
      .map((m) => freqFromCents(anchor, _foldToOctave(centsFromSa(m, anchor))))
      .toList(growable: false);
  final agreedSa = _median(folded);
  final worst =
      folded.map((m) => centsFromSa(m, agreedSa).abs()).reduce(max);
  if (worst > agreementBandCents) return null;
  return SaCalibration(
    saHz: agreedSa,
    agreementCents: worst,
    calibratedAt: DateTime.now(),
  );
}

/// Drift check for later sessions (plan 1.1 backstop).
/// Returns true when today's inferred tonic differs enough from the stored
/// Sa that the app should offer recalibration.
bool saDrifted({
  required double storedSaHz,
  required double todaysInferredSaHz,
  double thresholdCents = 50.0,
}) {
  return centsFromSa(todaysInferredSaHz, storedSaHz).abs() > thresholdCents;
}

// ---------------------------------------------------------------------------
// Raga-parameterized swara mapping (plan 1.2)
// ---------------------------------------------------------------------------

/// One swara's nominal position in a raga, in cents above Sa.
class SwaraDef {
  final String name; // 'Sa', 'Re', 'Ga', 'Pa', 'Dha', ...
  final double cents;
  const SwaraDef(this.name, this.cents);
}

/// A raga's pitch vocabulary. Add Bhairav (and later ragas) as new consts —
/// the mapping code below never changes.
class RagaSwaraTable {
  final String ragaName;
  final List<SwaraDef> swaras;
  const RagaSwaraTable(this.ragaName, this.swaras);

  /// Look up a raga's swara table by name (case-insensitive; a leading
  /// "Raag" is ignored, and the Bhopali/Bhoopali spellings both match).
  /// Returns null for a raga with no table yet — callers fall back to
  /// legacy behaviour. Register new ragas by adding their table
  /// constant here.
  static RagaSwaraTable? forRaga(String name) {
    var key = name.trim().toLowerCase();
    if (key.startsWith('raag ')) key = key.substring(5).trim();
    switch (key) {
      case 'bhopali':
      case 'bhoopali':
        return bhopaliTable;
      default:
        return null;
    }
  }
}

const bhopaliTable = RagaSwaraTable('Bhopali', [
  SwaraDef('Sa', 0),
  SwaraDef('Re', 200),
  SwaraDef('Ga', 400),
  SwaraDef('Pa', 700),
  SwaraDef('Dha', 900),
]);

/// Result of mapping one pitch to the raga's swara set.
class SwaraMatch {
  /// Nearest allowed swara.
  final String swara;

  /// Signed deviation in cents (+ = sharp of the swara, - = flat).
  final double deviationCents;

  /// True when inside the swara's acceptance band.
  final bool inBand;

  const SwaraMatch({
    required this.swara,
    required this.deviationCents,
    required this.inBand,
  });
}

/// Map [centsFromSa] to the nearest swara in [table].
/// Never snaps silently: when outside every band, [inBand] is false and the
/// caller reports it as off-target with direction (plan 1.2).
SwaraMatch nearestSwara(
  double centsFromSa,
  RagaSwaraTable table, {
  double bandCents = 50.0,
}) {
  // Normalize to one octave for the lookup; keep the original deviation sign.
  final pc = ((centsFromSa % 1200) + 1200) % 1200;
  SwaraDef? best;
  var bestDist = double.infinity;
  for (final s in table.swaras) {
    var d = (pc - s.cents).abs();
    d = min(d, 1200 - d); // octave wrap
    if (d < bestDist) {
      bestDist = d;
      best = s;
    }
  }
  // Signed deviation in the original (unwrapped) space.
  final signed = centsFromSa - best!.cents;
  final wrapped = ((signed + 600) % 1200) - 600;
  return SwaraMatch(
    swara: best.name,
    deviationCents: wrapped,
    inBand: bestDist <= bandCents,
  );
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

double _median(List<double> values) {
  final sorted = List<double>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2.0;
}

// ---------------------------------------------------------------------------
// Per-swara diagnosis (plan 1.2)
// ---------------------------------------------------------------------------

/// How one swara of a raga was sung in a take, relative to the singer's
/// Sa. Produced by diagnoseSwara in normalized_compare.dart; consumed by
/// the student feedback layer.
class SwaraDiagnosis {
  /// Median deviation within the in-tune band (<= 25 cents).
  static const String statusInTune = 'inTune';

  /// Median deviation beyond the in-tune band but still nearest this
  /// swara — flat (negative deviation) or sharp (positive).
  static const String statusFlat = 'flat';
  static const String statusSharp = 'sharp';

  /// Too few points near this swara to call it sung at all.
  static const String statusNotSung = 'notSung';

  /// Points cluster nearer a different pitch class than this swara
  /// (median |deviation| >= 75 cents): a wrong note or variant
  /// (e.g. komal Ga in Bhopali), not a tuning error.
  static const String statusWrongNote = 'wrongNote';

  final String swara;

  /// Signed median deviation in cents from the swara's exact position
  /// (negative = flat). 0.0 when status is notSung.
  final double medianDeviationCents;

  /// Voiced contour points whose nearest swara this is.
  final int pointCount;

  final String status;

  const SwaraDiagnosis({
    required this.swara,
    required this.medianDeviationCents,
    required this.pointCount,
    required this.status,
  });

  @override
  String toString() =>
      '$swara: $status (${medianDeviationCents.toStringAsFixed(0)}c, '
      '$pointCount pts)';
}

// ---------------------------------------------------------------------------
// Known-key Sa (plan 3b): note <-> frequency at A440 equal temperament
// ---------------------------------------------------------------------------

/// Pitch-class names, C first. A note's pitch class is `midi % 12`.
const List<String> pitchClassNames = [
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

/// Frequency in Hz of a MIDI note number (A440 equal temperament).
double hzForMidi(int midi) =>
    (440.0 * pow(2.0, (midi - 69) / 12.0)).toDouble();

/// Nearest MIDI note number for [hz] (A440 equal temperament).
int nearestMidiForHz(double hz) {
  assert(hz > 0, 'frequency must be positive');
  return (69 + 12 * log(hz / 440.0) / ln2).round();
}

/// Display name of a MIDI note, e.g. 56 -> 'G#3', 60 -> 'C4'.
String noteNameForMidi(int midi) =>
    '${pitchClassNames[midi % 12]}${(midi ~/ 12) - 1}';

/// Display name of the note nearest to [hz], e.g. 207.65 -> 'G#3'.
String noteNameForHz(double hz) => noteNameForMidi(nearestMidiForHz(hz));

/// The three octave candidates offered after a student picks a pitch
/// class: the class instance nearest A3 (220 Hz), plus the instances an
/// octave below and above it. The student resolves the octave by ear;
/// the app never guesses it.
List<int> candidateMidisForPitchClass(int pitchClass) {
  assert(pitchClass >= 0 && pitchClass < 12, 'pitch class must be 0..11');
  final center = pitchClass + 12 * ((57 - pitchClass) / 12).round();
  return [center - 12, center, center + 12];
}
