import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:sargam_app/services/normalized_compare.dart';
import 'package:sargam_app/services/sa_pitch.dart';

/// Bhopali aaroh: S R G P D S' in cents above Sa.
const aaroh = <double>[0, 200, 400, 700, 900, 1200];

/// Bhopali avroh: S' D P G R S.
const avroh = <double>[1200, 900, 700, 400, 200, 0];

/// Build a synthetic contour: [samplesPerNote] samples per note, each
/// offset by a deterministic per-position noise (in cents).
List<double> buildContour(
  double saHz,
  List<double> noteCents,
  List<double> noisePattern, {
  int samplesPerNote = 5,
}) {
  final out = <double>[];
  for (final note in noteCents) {
    for (var k = 0; k < samplesPerNote; k++) {
      out.add(freqFromCents(saHz, note + noisePattern[k % noisePattern.length]));
    }
  }
  return out;
}

// Two independent small-noise patterns (cents). Per-position differences
// have mean |.| = 1.5 cents.
const noiseA = <double>[0, 1.5, -1.0, 0.5, -0.5];
const noiseB = <double>[0.5, -1.0, 1.0, -1.5, 0];

// Slightly larger noise pair for the flat-Ga test: per-position differences
// are [1, -4, 5, -2, 1], mean |.| = 2.6 cents.
const noiseC = <double>[0, 2, -2, 1, -1];
const noiseD = <double>[1, -2, 3, -1, 0];

void main() {
  group('compareNormalized', () {
    test('1. identical relative performance at different Sa scores ~100', () {
      final ref = buildContour(220.0, aaroh, noiseA);
      final user = buildContour(138.59, aaroh, noiseB);
      final r = compareNormalized(
        referenceTrajectoryHz: ref,
        referenceSaHz: 220.0,
        userTrajectoryHz: user,
        userSaHz: 138.59,
      );
      expect(r.trajectoryScore, greaterThanOrEqualTo(98));
      expect(r.meanAbsDeviationCents, lessThan(5));
      expect(r.alignedDeviationsCents.length, 30);
    });

    test('2. legacy-killer: perfect intervals a fifth below reference Sa', () {
      final userSa = 220.0 * pow(2.0, -7 / 12).toDouble();
      final ref = buildContour(220.0, aaroh, noiseA);
      final user = buildContour(userSa, aaroh, noiseB);
      final r = compareNormalized(
        referenceTrajectoryHz: ref,
        referenceSaHz: 220.0,
        userTrajectoryHz: user,
        userSaHz: userSa,
      );
      expect(r.trajectoryScore, greaterThanOrEqualTo(95));
    });

    test('3. octave-down user: register is free under normalization', () {
      final ref = buildContour(220.0, aaroh, noiseA);
      final user = buildContour(110.0, aaroh, noiseB);
      final r = compareNormalized(
        referenceTrajectoryHz: ref,
        referenceSaHz: 220.0,
        userTrajectoryHz: user,
        userSaHz: 110.0,
      );
      expect(r.trajectoryScore, greaterThanOrEqualTo(95));
    });

    test('4. Ga flat by 30 cents: only Ga points deviate', () {
      final flatGa = <double>[0, 200, 370, 700, 900, 1200];
      final ref = buildContour(220.0, aaroh, noiseC);
      final user = buildContour(220.0, flatGa, noiseD);
      final r = compareNormalized(
        referenceTrajectoryHz: ref,
        referenceSaHz: 220.0,
        userTrajectoryHz: user,
        userSaHz: 220.0,
      );
      // Only 1/6 of points deviate (~30c); noise contributes ~2.6c elsewhere.
      // Expected meanAbs ~= (25*2.6 + 5*29.8)/30 ~= 7.1c.
      expect(r.meanAbsDeviationCents, greaterThan(5));
      expect(r.meanAbsDeviationCents, lessThan(30));
      expect(r.trajectoryScore, greaterThan(80));
      expect(r.trajectoryScore, lessThan(97));
    });

    test('6a. degenerate: empty user contour -> score 0, no throw', () {
      final ref = buildContour(220.0, aaroh, noiseA);
      final r = compareNormalized(
        referenceTrajectoryHz: ref,
        referenceSaHz: 220.0,
        userTrajectoryHz: const [],
        userSaHz: 220.0,
      );
      expect(r.trajectoryScore, 0);
      expect(r.meanAbsDeviationCents,
          NormalizedComparison.maxDeviationCentsSentinel);
      expect(r.alignedDeviationsCents, isEmpty);
    });

    test('6b. degenerate: all-zero user contour -> score 0, no throw', () {
      final ref = buildContour(220.0, aaroh, noiseA);
      final r = compareNormalized(
        referenceTrajectoryHz: ref,
        referenceSaHz: 220.0,
        userTrajectoryHz: const [0, 0, 0, 0],
        userSaHz: 220.0,
      );
      expect(r.trajectoryScore, 0);
      expect(r.alignedDeviationsCents, isEmpty);
    });

    test('6c. degenerate: empty reference contour -> score 0, no throw', () {
      final user = buildContour(220.0, aaroh, noiseA);
      final r = compareNormalized(
        referenceTrajectoryHz: const [],
        referenceSaHz: 220.0,
        userTrajectoryHz: user,
        userSaHz: 220.0,
      );
      expect(r.trajectoryScore, 0);
    });
  });

  group('estimateSaFromContour', () {
    bool withinCents(double estimateHz, double targetHz, double cents) {
      return estimateHz > 0 &&
          centsFromSa(estimateHz, targetHz).abs() <= cents;
    }

    test('5a. noisy aaroh at Sa 196 -> within 20 cents', () {
      final contour = buildContour(196.0, aaroh, const [0, 4, -3, 2, -2]);
      final est = estimateSaFromContour(contour);
      expect(withinCents(est, 196.0, 20), isTrue,
          reason: 'estimate was $est Hz');
    });

    test('5b. avroh at Sa 196 -> within 20 cents', () {
      final contour = buildContour(196.0, avroh, const [0, 4, -3, 2, -2]);
      final est = estimateSaFromContour(contour);
      expect(withinCents(est, 196.0, 20), isTrue,
          reason: 'estimate was $est Hz');
    });

    test('5c. aaroh at Sa 220 with upper Sa -> returns ~220, not ~440', () {
      final contour = buildContour(220.0, aaroh, const [0, 4, -3, 2, -2]);
      final est = estimateSaFromContour(contour);
      expect(withinCents(est, 220.0, 20), isTrue,
          reason: 'estimate was $est Hz');
      expect(withinCents(est, 440.0, 20), isFalse,
          reason: 'estimate was $est Hz (upper octave!)');
    });

    test('5d. aaroh at Sa 196 with octave-down ghosts -> still ~196', () {
      // Regression (device, 2026-10-11): the estimator returned 95.45 Hz
      // for a ~191 Hz Sa because autocorrelation octave-down ghosts formed
      // the lowest Sa-class cluster and the old rule took the lowest.
      final clean = buildContour(196.0, aaroh, const [0, 4, -3, 2, -2]);
      final ghosted = <double>[];
      for (var i = 0; i < clean.length; i++) {
        ghosted.add(i % 3 == 0 ? clean[i] / 2 : clean[i]);
      }
      final est = estimateSaFromContour(ghosted);
      expect(withinCents(est, 196.0, 20), isTrue,
          reason: 'estimate was $est Hz');
      expect(withinCents(est, 98.0, 20), isFalse,
          reason: 'estimate was $est Hz (ghost octave!)');
    });

    test('5e. avroh-only with slightly more upper-Sa samples -> ~196', () {
      // Regression (VM probe, 2026-10-11): a vibrato avroh contour gave
      // upper-Sa cluster 34 samples vs lower-Sa 33; the pure
      // densest-cluster rule returned 392 Hz. The hybrid rule (lowest
      // cluster with >= half the densest count) must still return 196.
      final contour = buildContour(196.0, avroh, const [0, 4, -3, 2, -2]);
      // Force the imbalance: duplicate a few upper-Sa (392 Hz) samples.
      final upper = contour.where((f) => f > 300).take(3).toList();
      final est = estimateSaFromContour([...contour, ...upper]);
      expect(withinCents(est, 196.0, 20), isTrue,
          reason: 'estimate was $est Hz');
      expect(withinCents(est, 392.0, 20), isFalse,
          reason: 'estimate was $est Hz (upper octave!)');
    });

    test('6d. empty contour -> 0', () {
      expect(estimateSaFromContour(const []), 0);
    });

    test('6e. all-zero contour -> 0', () {
      expect(estimateSaFromContour(const [0, 0, 0]), 0);
    });
  });
}
