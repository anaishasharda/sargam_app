import 'dart:math';

import 'sa_pitch.dart';

/// Sa-normalized trajectory comparison (plan 1.8).
///
/// The legacy `compareAudio` compared raw Hz ratios between the reference
/// recording and the student. That punishes a student purely for having a
/// different Sa: sing a perfect Bhopali aaroh at Sa = D against a reference
/// recorded at Sa = C# and the old trajectory score collapsed (~46% in the
/// 2026-10-10 device logs), even with flawless relative intonation.
///
/// This engine instead converts each singer's contour to cents relative to
/// THAT singer's own Sa (via [centsFromSa]) and compares in cents space.
/// A perfect performance at any Sa — or in any octave — scores ~100.
/// Nothing musical is ever scored in absolute Hz.
///
/// Pure Dart (only depends on sa_pitch.dart primitives), so it can be
/// unit-tested standalone and later wired into the app's compareAudio.

/// Result of a normalized trajectory comparison.
class NormalizedComparison {
  /// 0..100. Higher = user's intonation contour matches the reference's,
  /// after each is normalized to its own Sa.
  final double trajectoryScore;

  /// Mean |user - ref| deviation across aligned points, in cents.
  /// On degenerate input (no comparable points) this is
  /// [NormalizedComparison.maxDeviationCentsSentinel], not infinity.
  final double meanAbsDeviationCents;

  /// Per-aligned-point signed deviation (user - ref), in cents.
  /// Positive = user sharp of the reference at that point.
  /// Empty on degenerate input.
  final List<double> alignedDeviationsCents;

  const NormalizedComparison({
    required this.trajectoryScore,
    required this.meanAbsDeviationCents,
    required this.alignedDeviationsCents,
  });

  /// Sentinel "worst possible" mean deviation used when no points could be
  /// compared. One full octave of average error is a natural cap: anything
  /// at or beyond it is simply "no match", and the score formula floors at 0
  /// there anyway. Using a finite sentinel keeps callers NaN/infinity-free.
  static const double maxDeviationCentsSentinel = 1200.0;
}

/// Tunable slope: score points lost per cent of mean absolute deviation,
/// i.e. score = 100 - 0.5 * meanAbsDeviationCents.
///   50c mean deviation  -> 75
///  100c mean deviation  -> 50  (a full semitone off on average)
///  200c mean deviation  -> 0
/// This is a starting hypothesis (plan 1.5 will tune it against labeled
/// recordings); it is deliberately gentler than the legacy raw-ratio slope,
/// which mapped a ~5.9% Hz error (≈100c) to a 30-point loss before octave
/// folding muddied it further.
const double _scorePointsPerCent = 0.5;

/// Compare [userTrajectoryHz] against [referenceTrajectoryHz], each
/// normalized to its own Sa.
///
/// Alignment intentionally mirrors the legacy code's proportional
/// resampling, so scores change only because of normalization, not because
/// of a new alignment policy: the number of compared points is
/// min(len(ref), len(user)); the reference index for point i is
/// (i * refLen / comparisons).floor(); the user index is i.
/// Pairs where either pitch is <= 0 (unvoiced/dropout) are skipped.
/// Deviations are signed cents (user - ref). There is NO octave folding:
/// after Sa-normalization an octave error is a real 1200-cent error and is
/// scored as one.
///
/// Never throws. Degenerate input (either contour empty, a non-positive
/// Sa, or no valid pairs) returns score 0 with the sentinel mean deviation.
NormalizedComparison compareNormalized({
  required List<double> referenceTrajectoryHz,
  required double referenceSaHz,
  required List<double> userTrajectoryHz,
  required double userSaHz,
}) {
  const degenerate = NormalizedComparison(
    trajectoryScore: 0.0,
    meanAbsDeviationCents:
        NormalizedComparison.maxDeviationCentsSentinel,
    alignedDeviationsCents: <double>[],
  );

  if (referenceTrajectoryHz.isEmpty || userTrajectoryHz.isEmpty) {
    return degenerate;
  }
  // centsFromSa asserts positive frequencies; guard here so bad stored data
  // degrades to a zero score instead of an exception.
  if (referenceSaHz <= 0 || userSaHz <= 0) return degenerate;

  final refLen = referenceTrajectoryHz.length;
  final userLen = userTrajectoryHz.length;
  final comparisons = min(refLen, userLen);

  final deviations = <double>[];
  var totalAbsDeviation = 0.0;
  for (var i = 0; i < comparisons; i++) {
    final refIndex = (i * refLen / comparisons).floor();
    final refPitch = referenceTrajectoryHz[refIndex];
    final userPitch = userTrajectoryHz[i];
    if (refPitch <= 0 || userPitch <= 0) continue;
    final refCents = centsFromSa(refPitch, referenceSaHz);
    final userCents = centsFromSa(userPitch, userSaHz);
    final deviation = userCents - refCents;
    deviations.add(deviation);
    totalAbsDeviation += deviation.abs();
  }

  if (deviations.isEmpty) return degenerate;

  final meanAbs = totalAbsDeviation / deviations.length;
  final score = max(0.0, 100.0 - _scorePointsPerCent * meanAbs);
  return NormalizedComparison(
    trajectoryScore: score,
    meanAbsDeviationCents: meanAbs,
    alignedDeviationsCents: deviations,
  );
}

/// Estimate a recording's Sa (in Hz) from its pitch contour alone.
///
/// Used for reference recordings, which arrive without a stored Sa
/// (plan 1.8: "analyze the reference once and store its Sa").
///
/// Method:
///  1. Drop unvoiced samples (<= 0). If none remain, return 0.
///  2. Fold every sample to a pitch class — cents above a fixed 110 Hz
///     reference, mod 1200 — and histogram into 10-cent bins. The densest
///     bin's pitch class is the Sa class. Folding is what makes this work:
///     an aaroh touches Sa twice (low Sa and Sa'), an avroh likewise, so
///     the Sa class collects more samples than any single other swara.
///  3. Among samples whose pitch class lies within ±50 cents of the Sa
///     class, cluster by octave and take the LOWEST cluster, returning its
///     median Hz. Rationale: aaroh/avroh both touch the low Sa, and the
///     lowest Sa cluster is the tonic in the octave actually sung —
///     normalization depends on getting that octave right, because the
///     stored Sa anchors everything downstream (a Sa estimated an octave
///     high would still normalize intervals correctly, but would mislead
///     drift checks and the teacher's by-ear verification).
///
/// Fallback: if the histogram is ambiguous (too few voiced samples, or no
/// bin collects at least 2 samples), return the median of all voiced
/// samples — a crude but bounded guess for pathological input.
double estimateSaFromContour(List<double> trajectoryHz) {
  final voiced = trajectoryHz.where((f) => f > 0).toList(growable: false);
  if (voiced.isEmpty) return 0.0;
  if (voiced.length < 5) return _median(voiced);

  const binWidthCents = 10.0;
  const binCount = 120; // 1200 / 10
  final bins = List<int>.filled(binCount, 0);
  final pitchClasses = List<double>.filled(voiced.length, 0.0);
  for (var i = 0; i < voiced.length; i++) {
    final pc = _pitchClassCents(voiced[i]);
    pitchClasses[i] = pc;
    var bin = (pc / binWidthCents).floor();
    if (bin < 0) bin = 0;
    if (bin >= binCount) bin = binCount - 1;
    bins[bin]++;
  }
  var densestBin = 0;
  for (var b = 1; b < binCount; b++) {
    if (bins[b] > bins[densestBin]) densestBin = b;
  }
  if (bins[densestBin] < 2) return _median(voiced);
  final saClassCenter = densestBin * binWidthCents + binWidthCents / 2;

  final saSamples = <double>[];
  for (var i = 0; i < voiced.length; i++) {
    var d = (pitchClasses[i] - saClassCenter).abs();
    d = min(d, 1200.0 - d); // circular distance
    if (d <= 50.0) saSamples.add(voiced[i]);
  }
  if (saSamples.isEmpty) return _median(voiced);

  // Cluster the Sa-class samples by octave: sorted samples further apart
  // than 100 cents belong to different octaves (true Sa octaves are ~1200
  // cents apart, so the threshold has wide margin on both sides).
  //
  // Cluster choice — a cluster qualifies as Sa only if BOTH:
  //  (i) it has at least half the densest cluster's count, and
  //  (ii) at most 10% of voiced points lie more than 1300 cents above
  //      it (Sa is the floor of a one-octave exercise; a candidate an
  //      octave too low turns the scale into a two-octave span).
  // The lowest qualifying cluster wins. Both single-criterion rules
  // have a demonstrated failure:
  //  * Lowest cluster (pre-2026-10-11): autocorrelation octave-down
  //    "ghost" samples form a sparse cluster below the true Sa
  //    (device: 95.45 Hz for a ~191 Hz Sa) — any ghost presence won.
  //  * Densest cluster: on an avroh-only take, lower/upper Sa counts
  //    can tip either way (VM probe: upper 34 vs lower 33 -> 392 Hz).
  // Counts alone also tie at exactly 50% (30-point unit contour:
  // ghost 2 vs true 4) — the span rule (ii) is what rejects that
  // ghost: 13% of its points sit >1300c above it, vs ~0% for a true
  // Sa. On real contours (200+ points) both margins are wide.
  // (Ghosts larger than half the true cluster AND in-span would
  // still win — that is detector territory, plan 1.3.)
  saSamples.sort();
  final clusters = <List<double>>[<double>[saSamples.first]];
  for (var i = 1; i < saSamples.length; i++) {
    final gapCents = centsFromSa(saSamples[i], saSamples[i - 1]);
    if (gapCents > 100.0) clusters.add(<double>[]);
    clusters.last.add(saSamples[i]);
  }
  var maxCount = 0;
  for (final c in clusters) {
    if (c.length > maxCount) maxCount = c.length;
  }
  List<double> densest = clusters.first;
  for (final c in clusters) {
    if (c.length > densest.length) densest = c;
  }
  for (final c in clusters) {
    if (c.length * 2 < maxCount) continue;
    final median = _median(c);
    var above = 0;
    for (final f in voiced) {
      if (centsFromSa(f, median) > 1300.0) above++;
    }
    if (above * 10 <= voiced.length) return median;
  }
  return _median(densest);
}

/// Pitch class of [freqHz] in cents (0..1200), relative to a fixed
/// 110 Hz reference so classes are comparable across samples.
/// (110 Hz is arbitrary; only mod-1200 position matters.)
double _pitchClassCents(double freqHz) {
  final cents = 1200.0 * log(freqHz / 110.0) / ln2;
  return ((cents % 1200.0) + 1200.0) % 1200.0;
}

double _median(List<double> values) {
  final sorted = List<double>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2.0;
}

// ---------------------------------------------------------------------------
// Per-swara diagnosis + constrained note sets (plan 1.2)
// ---------------------------------------------------------------------------

/// A swara needs at least this many contour points before it counts as
/// sung: 2% of the voiced points, with an absolute floor of 3.
int _minSwaraPoints(int voicedCount) {
  final share = (voicedCount * 0.02).ceil();
  return share > 3 ? share : 3;
}

/// Bucket voiced contour points by their nearest swara in [table],
/// keeping each point's signed deviation from that swara. Points are
/// assigned by nearest swara with no band limit, so a consistently
/// wrong note lands in its nearest swara's bucket with a large
/// deviation — that is what diagnoseSwara's wrongNote status reads.
Map<String, List<double>> _bucketBySwara(
  List<double> contour,
  double saHz,
  RagaSwaraTable table,
) {
  final buckets = <String, List<double>>{
    for (final s in table.swaras) s.name: <double>[],
  };
  for (final f in contour) {
    if (f <= 0) continue;
    final match = nearestSwara(centsFromSa(f, saHz), table);
    buckets[match.swara]!.add(match.deviationCents);
  }
  return buckets;
}

/// Diagnose how each swara of [table] was sung in [userContour],
/// relative to [userSaHz]: one SwaraDiagnosis per swara of the raga,
/// in table order. Returns an empty list when there is nothing to
/// diagnose (no Sa, or no voiced points).
List<SwaraDiagnosis> diagnoseSwara(
  List<double> userContour,
  double userSaHz,
  RagaSwaraTable table,
) {
  if (userSaHz <= 0) return const [];
  final voiced = userContour.where((f) => f > 0).length;
  if (voiced == 0) return const [];
  final buckets = _bucketBySwara(userContour, userSaHz, table);
  final minPoints = _minSwaraPoints(voiced);
  final out = <SwaraDiagnosis>[];
  for (final s in table.swaras) {
    final devs = buckets[s.name]!;
    if (devs.length < minPoints) {
      out.add(SwaraDiagnosis(
        swara: s.name,
        medianDeviationCents: 0.0,
        pointCount: devs.length,
        status: SwaraDiagnosis.statusNotSung,
      ));
      continue;
    }
    final median = _median(devs);
    // Epsilon-tolerant edges: a deviation constructed at exactly the
    // band edge comes back from the Hz roundtrip a hair over or under,
    // and the classification must not hinge on the ninth decimal.
    const eps = 1e-6;
    final status = median.abs() <= 25.0 + eps
        ? SwaraDiagnosis.statusInTune
        : median.abs() >= 75.0 - eps
            ? SwaraDiagnosis.statusWrongNote
            : median < 0
                ? SwaraDiagnosis.statusFlat
                : SwaraDiagnosis.statusSharp;
    out.add(SwaraDiagnosis(
      swara: s.name,
      medianDeviationCents: median,
      pointCount: devs.length,
      status: status,
    ));
  }
  return out;
}

/// The raga swaras recognisably sung in [contour] relative to [saHz]:
/// diagnosed in tune, flat, or sharp. A swara that was not sung, or was
/// replaced by a wrong note, is absent — so set differences against
/// the expected notes give musically meaningful missed notes, and
/// notes outside the raga can never appear.
Set<String> constrainedSungNotes(
  List<double> contour,
  double saHz,
  RagaSwaraTable table,
) {
  return {
    for (final d in diagnoseSwara(contour, saHz, table))
      if (d.status == SwaraDiagnosis.statusInTune ||
          d.status == SwaraDiagnosis.statusFlat ||
          d.status == SwaraDiagnosis.statusSharp)
        d.swara,
  };
}

/// Outcome of a same-session Sa drift check (plan 3c, core).
class SaDriftCheck {
  /// The student's stored Sa (Hz).
  final double storedSaHz;

  /// Sa inferred from today's take (Hz).
  final double todaysSaHz;

  /// Signed deviation of today's Sa from the stored Sa, in cents.
  final double deviationCents;

  /// True when |deviation| exceeds the recalibration threshold (50c).
  final bool drifted;

  const SaDriftCheck({
    required this.storedSaHz,
    required this.todaysSaHz,
    required this.deviationCents,
    required this.drifted,
  });

  @override
  String toString() =>
      'SaDriftCheck(stored ${storedSaHz.toStringAsFixed(2)} Hz, '
      'today ${todaysSaHz.toStringAsFixed(2)} Hz, '
      '${deviationCents >= 0 ? '+' : ''}${deviationCents.toStringAsFixed(0)}c, '
      'drifted: $drifted)';
}

/// Estimate today's Sa from the contour points that sit in the stored
/// Sa's pitch class, folded into the stored Sa's octave.
///
/// Drift detection does not need blind tonic discovery: the stored Sa
/// defines the class, and octave ghosts share that class, so they fold
/// in harmlessly instead of dragging the estimate to a ghost cluster —
/// the failure estimateSaFromContour showed on a real user take
/// (84.48 Hz returned for a take sung at the stored 207.65 Hz, while
/// its per-swara diagnosis read every note within -51..-3 cents).
/// Returns null when too few points fall in the class window to judge.
double? _todaysSaFromStoredClass(List<double> contour, double storedSaHz) {
  final folded = <double>[];
  for (final f in contour) {
    if (f <= 0) continue;
    final pc = ((centsFromSa(f, storedSaHz) + 600) % 1200) - 600;
    if (pc.abs() <= 100) folded.add(freqFromCents(storedSaHz, pc));
  }
  if (folded.length < 5) return null;
  return _median(folded);
}

/// Plan 3c core: compare the Sa inferred from today's take against the
/// stored Sa. Returns null when no verdict is possible (no stored Sa, or
/// too few of the take's points sit in the stored Sa's pitch class).
/// The UI prompt that acts on a drifted verdict is plumbed in
/// separately, after the calibration screen (3b) exists to route to.
///
/// The estimate is anchored to the stored Sa's pitch class (see
/// _todaysSaFromStoredClass): it judges takes sung near the stored Sa
/// precisely, and returns no verdict for a take with too few points in
/// that class (e.g. sung far from the stored Sa throughout) rather
/// than guessing a tonic. Such a take's per-swara diagnosis, computed
/// against the stored Sa, still carries the signal.
SaDriftCheck? checkSaDrift({
  required List<double> userTrajectoryHz,
  required double? storedSaHz,
}) {
  if (storedSaHz == null || storedSaHz <= 0) return null;
  final todaysSaHz = _todaysSaFromStoredClass(userTrajectoryHz, storedSaHz);
  if (todaysSaHz == null) return null;
  return SaDriftCheck(
    storedSaHz: storedSaHz,
    todaysSaHz: todaysSaHz,
    deviationCents: centsFromSa(todaysSaHz, storedSaHz),
    drifted: saDrifted(
      storedSaHz: storedSaHz,
      todaysInferredSaHz: todaysSaHz,
    ),
  );
}
