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

  group('RagaSwaraTable.forRaga (1.2)', () {
    test('known spellings resolve to the Bhopali table', () {
      expect(RagaSwaraTable.forRaga('Bhopali'), same(bhopaliTable));
      expect(RagaSwaraTable.forRaga('bhoopali'), same(bhopaliTable));
      expect(RagaSwaraTable.forRaga('Raag Bhopali'), same(bhopaliTable));
      expect(RagaSwaraTable.forRaga(' BHOPALI '), same(bhopaliTable));
    });

    test('unknown raga -> null (legacy fallback)', () {
      expect(RagaSwaraTable.forRaga('Yaman'), isNull);
      expect(RagaSwaraTable.forRaga(''), isNull);
    });
  });

  group('diagnoseSwara (1.2)', () {
    final fullScale = <double>[...aaroh, ...avroh];

    SwaraDiagnosis byName(List<SwaraDiagnosis> ds, String name) =>
        ds.firstWhere((d) => d.swara == name);

    test('perfect take: every swara in tune, Sa pools both octaves', () {
      final ds = diagnoseSwara(
          buildContour(196.0, fullScale, noiseA), 196.0, bhopaliTable);
      expect(ds.length, 5);
      for (final d in ds) {
        expect(d.status, SwaraDiagnosis.statusInTune, reason: '$d');
      }
      expect(byName(ds, 'Sa').pointCount, 20); // 4 Sa-position notes x5
      expect(byName(ds, 'Ga').pointCount, 10);
    });

    test('Ga flat by 30: Ga flat ~-30, everything else in tune', () {
      final flat = <double>[
        0, 200, 370, 700, 900, 1200, 1200, 900, 700, 370, 200, 0
      ];
      final ds = diagnoseSwara(
          buildContour(196.0, flat, noiseA), 196.0, bhopaliTable);
      final ga = byName(ds, 'Ga');
      expect(ga.status, SwaraDiagnosis.statusFlat, reason: '$ga');
      expect(ga.medianDeviationCents, closeTo(-30.0, 3.0));
      expect(byName(ds, 'Pa').status, SwaraDiagnosis.statusInTune);
      // A flat Ga still counts as sung Ga.
      expect(
          constrainedSungNotes(
              buildContour(196.0, flat, noiseA), 196.0, bhopaliTable),
          contains('Ga'));
    });

    test('Ga replaced by a 500c note: wrongNote, and Ga not sung', () {
      final wrong = <double>[
        0, 200, 500, 700, 900, 1200, 1200, 900, 700, 500, 200, 0
      ];
      final contour = buildContour(196.0, wrong, noiseA);
      final ds = diagnoseSwara(contour, 196.0, bhopaliTable);
      final ga = byName(ds, 'Ga');
      expect(ga.status, SwaraDiagnosis.statusWrongNote, reason: '$ga');
      expect(ga.medianDeviationCents, closeTo(100.0, 3.0));
      expect(constrainedSungNotes(contour, 196.0, bhopaliTable),
          {'Sa', 'Re', 'Pa', 'Dha'});
    });

    test('missing Dha: notSung with zero points', () {
      final noDha = <double>[0, 200, 400, 700, 1200, 1200, 700, 400, 200, 0];
      final ds = diagnoseSwara(
          buildContour(196.0, noDha, noiseA), 196.0, bhopaliTable);
      final dha = byName(ds, 'Dha');
      expect(dha.status, SwaraDiagnosis.statusNotSung);
      expect(dha.pointCount, 0);
    });

    test('Re sharp by 45: sharp status', () {
      final sharp = <double>[
        0, 245, 400, 700, 900, 1200, 1200, 900, 700, 400, 245, 0
      ];
      final ds = diagnoseSwara(
          buildContour(196.0, sharp, noiseA), 196.0, bhopaliTable);
      expect(byName(ds, 'Re').status, SwaraDiagnosis.statusSharp);
    });

    test('status boundaries on exact-deviation contours', () {
      List<double> held(double cents) =>
          List.filled(12, freqFromCents(196.0, cents));
      String gaStatus(double cents) => byName(
              diagnoseSwara(held(cents), 196.0, bhopaliTable), 'Ga')
          .status;
      expect(gaStatus(400 - 25), SwaraDiagnosis.statusInTune);
      expect(gaStatus(400 + 25), SwaraDiagnosis.statusInTune);
      expect(gaStatus(400 - 40), SwaraDiagnosis.statusFlat);
      expect(gaStatus(400 + 74), SwaraDiagnosis.statusSharp);
      expect(gaStatus(400 - 75), SwaraDiagnosis.statusWrongNote);
      expect(gaStatus(400 + 75), SwaraDiagnosis.statusWrongNote);
    });

    test('degenerate inputs: no diagnosis, no throw', () {
      expect(diagnoseSwara(const [], 196.0, bhopaliTable), isEmpty);
      expect(diagnoseSwara(const [0.0, 0.0], 196.0, bhopaliTable), isEmpty);
      expect(
          diagnoseSwara(
              buildContour(196.0, fullScale, noiseA), 0.0, bhopaliTable),
          isEmpty);
    });

    test('stray wrong-region points cannot create a non-raga note', () {
      // A few stray points in the 500c "Ma region" on top of a correct
      // scale: the device bug reported Ma as missed in Bhopali. The
      // constrained set is built only from table swaras, so Ma is
      // impossible — and a handful of strays must not flip Ga's own
      // diagnosis either (median, not mean). A *dominant* wrong cluster
      // flipping Ga to wrongNote is the designed behaviour, pinned by
      // the 500c sequence test above.
      final contour = buildContour(196.0, fullScale, noiseA)
        ..addAll(List.filled(6, freqFromCents(196.0, 500)));
      final sung = constrainedSungNotes(contour, 196.0, bhopaliTable);
      expect(sung, {'Sa', 'Re', 'Ga', 'Pa', 'Dha'});
      expect(sung.contains('Ma'), isFalse);
    });
  });
  driftTests();
}

void driftTests() {
  group('checkSaDrift (plan 3c core)', () {
    const noiseA = <double>[0, 5, -5, 10, -10];
    const scale = <double>[0, 200, 400, 700, 900, 1200];

    test('null when there is no stored Sa', () {
      final contour = buildContour(207.65, scale, noiseA);
      expect(checkSaDrift(userTrajectoryHz: contour, storedSaHz: null),
          isNull);
      expect(checkSaDrift(userTrajectoryHz: contour, storedSaHz: 0),
          isNull);
    });

    test('null when the take has no voiced pitch', () {
      expect(checkSaDrift(userTrajectoryHz: const [], storedSaHz: 207.65),
          isNull);
      expect(
          checkSaDrift(
              userTrajectoryHz: const [0.0, 0.0, 0.0], storedSaHz: 207.65),
          isNull);
    });

    test('in-tune take: no drift, small deviation', () {
      final contour = buildContour(207.65, scale, noiseA);
      final r = checkSaDrift(userTrajectoryHz: contour, storedSaHz: 207.65)!;
      expect(r.drifted, isFalse);
      expect(r.deviationCents.abs(), lessThan(25));
    });

    test('take sung a whole tone high: no verdict, by design', () {
      // The anchored estimate only judges takes sung near the stored
      // Sa. A whole-tone shift leaves almost no points in the stored
      // pitch class, so checkSaDrift returns null instead of guessing
      // a tonic; the take's diagnosis against the stored Sa carries
      // the signal (see checkSaDrift's doc comment).
      final contour = buildContour(233.08, scale, noiseA);
      expect(checkSaDrift(userTrajectoryHz: contour, storedSaHz: 207.65),
          isNull);
    });

    test('take sung ~80c sharp: drift flagged', () {
      final sharpSa = 207.65 * 1.04729; // ~ +80 cents
      final contour = buildContour(sharpSa, scale, noiseA);
      final r = checkSaDrift(userTrajectoryHz: contour, storedSaHz: 207.65)!;
      expect(r.drifted, isTrue);
      expect(r.deviationCents, greaterThan(50));
    });

    test('ghost-heavy take at the stored Sa: no drift (84.48 regression)',
        () {
      // Regression for the 2026-10-21 device run: a take sung AT the
      // stored Sa whose contour carries heavy octave-down ghosts read
      // 'today 84.48 Hz, drifted: true' under blind tonic estimation.
      final clean = buildContour(207.65, scale, noiseA);
      final contour = <double>[
        for (var i = 0; i < clean.length; i++)
          i % 3 == 0 ? clean[i] / 2 : clean[i],
      ];
      final r = checkSaDrift(userTrajectoryHz: contour, storedSaHz: 207.65)!;
      expect(r.drifted, isFalse);
      expect(r.deviationCents.abs(), lessThan(25));
    });

    test('null when no points sit in the stored Sa pitch class', () {
      final contour = buildContour(207.65, const [200, 400, 700, 900],
          noiseA);
      expect(checkSaDrift(userTrajectoryHz: contour, storedSaHz: 207.65),
          isNull);
    });

    test('take sung ~40c flat: under threshold, no drift', () {
      final flatSa = 207.65 * 0.97716; // ~ -40 cents
      final contour = buildContour(flatSa, scale, noiseA);
      final r = checkSaDrift(userTrajectoryHz: contour, storedSaHz: 207.65)!;
      expect(r.drifted, isFalse);
      expect(r.deviationCents, lessThan(-25));
    });
  });
}
