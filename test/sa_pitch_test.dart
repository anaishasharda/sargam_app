import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sargam_app/services/sa_pitch.dart';

/// Unit tests for the Sa-relative pitch foundation (plan 1.1 / 1.2).
/// Run: flutter test test/sa_pitch_test.dart   (no device needed)
void main() {
  group('centsFromSa', () {
    test('same frequency is 0 cents', () {
      expect(centsFromSa(440.0, 440.0), equals(0.0));
    });

    test('octave up is 1200 cents', () {
      expect(centsFromSa(880.0, 440.0), closeTo(1200.0, 1e-9));
    });

    test('one semitone up is 100 cents', () {
      final semitone = 440.0 * pow(2.0, 1 / 12);
      expect(centsFromSa(semitone, 440.0), closeTo(100.0, 1e-6));
    });

    test('two semitones up is 200 cents (the Sa-offset case)', () {
      final twoSemitones = 440.0 * pow(2.0, 2 / 12);
      expect(centsFromSa(twoSemitones, 440.0), closeTo(200.0, 1e-6));
    });
  });

  group('analyzeSaTake', () {
    test('steady hold is stable', () {
      // A held Sa with tiny wobble: 440Hz +/- 0.5%
      final samples =
          List<double>.generate(200, (i) => 440.0 * (1 + 0.005 * sin(i)));
      final take = analyzeSaTake(samples)!;
      expect(take.isStable, isTrue);
      expect(take.medianHz, closeTo(440.0, 5.0));
    });

    test('wobbly hold is rejected', () {
      // Drift of +/- 4% (~ +/- 68 cents) — a kid sliding around
      final samples =
          List<double>.generate(200, (i) => 440.0 * (1 + 0.04 * sin(i / 3)));
      final take = analyzeSaTake(samples)!;
      expect(take.isStable, isFalse);
    });

    test('empty take is unusable, not a crash', () {
      expect(analyzeSaTake(const <double>[]), isNull);
    });

    test('unvoiced take is unusable, not a crash', () {
      expect(analyzeSaTake(const <double>[0.0, 0.0, -1.0]), isNull);
    });
  });

  group('calibrateSa', () {
    SaTakeResult take(double hz) =>
        SaTakeResult(medianHz: hz, stdDevCents: 10.0);

    test('three agreeing takes calibrate', () {
      final result = calibrateSa([take(440.0), take(442.0), take(439.0)]);
      expect(result, isNotNull);
      expect(result!.saHz, closeTo(440.0, 3.0));
    });

    test('outlier take fails calibration', () {
      // Third take ~70 cents sharp — disagreement beyond the 30c gate
      final result = calibrateSa([take(440.0), take(441.0), take(458.0)]);
      expect(result, isNull);
    });

    test('unstable take fails calibration', () {
      final result = calibrateSa([
        take(440.0),
        take(441.0),
        const SaTakeResult(medianHz: 440.0, stdDevCents: 60.0),
      ]);
      expect(result, isNull);
    });
  });

  group('saDrifted', () {
    test('same Sa does not drift', () {
      expect(saDrifted(storedSaHz: 440.0, todaysInferredSaHz: 445.0), isFalse);
    });

    test('semitone shift drifts', () {
      final shifted = 440.0 * pow(2.0, 1 / 12);
      expect(
          saDrifted(storedSaHz: 440.0, todaysInferredSaHz: shifted), isTrue);
    });
  });

  group('nearestSwara (Bhopali)', () {
    test('exact swara centers snap in-band', () {
      expect(nearestSwara(0.0, bhopaliTable).swara, equals('Sa'));
      expect(nearestSwara(200.0, bhopaliTable).swara, equals('Re'));
      expect(nearestSwara(400.0, bhopaliTable).swara, equals('Ga'));
      expect(nearestSwara(700.0, bhopaliTable).swara, equals('Pa'));
      expect(nearestSwara(900.0, bhopaliTable).swara, equals('Dha'));
      expect(nearestSwara(200.0, bhopaliTable).inBand, isTrue);
    });

    test('pitch between swaras reports off-target, not snapped', () {
      // 90 cents: between Sa and Re, outside every band
      final m = nearestSwara(90.0, bhopaliTable);
      expect(m.inBand, isFalse);
      expect(m.deviationCents, closeTo(90.0, 1e-9)); // sharp of Sa
    });

    test('slightly flat Ga reports negative deviation', () {
      final m = nearestSwara(370.0, bhopaliTable);
      expect(m.swara, equals('Ga'));
      expect(m.inBand, isTrue);
      expect(m.deviationCents, closeTo(-30.0, 1e-9));
    });

    test('Ma region never produces Ma in Bhopali mode', () {
      // 500 cents is Ma territory — must map to nearest allowed, off-target
      final m = nearestSwara(500.0, bhopaliTable);
      expect(m.swara, isNot(equals('Ma')));
      expect(m.inBand, isFalse);
    });
  });
}
