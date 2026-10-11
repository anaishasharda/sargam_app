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

  /// Std dev of the take's samples, in cents relative to [medianHz].
  final double stdDevCents;

  const SaTakeResult({required this.medianHz, required this.stdDevCents});

  /// A take counts as usable only if the held note was steady.
  bool get isStable => stdDevCents <= 25.0;
}

/// Analyze one take from its raw YIN pitch samples (Hz).
/// The caller should pass only the middle ~2 seconds (attack skipped);
/// unvoiced/dropout samples (<= 0) are ignored here.
SaTakeResult analyzeSaTake(List<double> pitchSamplesHz) {
  final voiced =
      pitchSamplesHz.where((f) => f > 0).toList(growable: false);
  assert(voiced.isNotEmpty, 'take has no voiced samples');
  final median = _median(voiced);
  final mean = voiced.reduce((a, b) => a + b) / voiced.length;
  final variance = voiced
          .map((f) => pow(centsFromSa(f, median), 2))
          .reduce((a, b) => a + b) /
      voiced.length;
  return SaTakeResult(
    medianHz: median,
    stdDevCents: sqrt(variance),
  );
}

/// A completed calibration: the student's Sa, agreed across takes.
class SaCalibration {
  /// Agreed Sa in Hz (median of take medians).
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
SaCalibration? calibrateSa(
  List<SaTakeResult> takes, {
  double agreementBandCents = 30.0,
}) {
  if (takes.length < 3) return null;
  if (takes.any((t) => !t.isStable)) return null;
  final medians = takes.map((t) => t.medianHz).toList(growable: false);
  final agreedSa = _median(medians);
  final worst =
      medians.map((m) => centsFromSa(m, agreedSa).abs()).reduce(max);
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
