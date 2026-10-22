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

    test('octave-down ghost frames do not make a steady take unstable',
        () {
      // Regression (device, 2026-10-21): a classical singer's steady held
      // Sa at ~225 Hz read ~40% of frames an octave down; the unfolded
      // stdDev scored ~600c and every take was rejected as 'wobbled'.
      final samples = <double>[
        for (var i = 0; i < 100; i++) i % 5 < 2 ? 112.5 : 225.0,
      ];
      final take = analyzeSaTake(samples)!;
      expect(take.medianHz, 225.0);
      expect(take.isStable, isTrue);
    });

    test('octave-up ghost frames do not make a steady take unstable', () {
      final samples = <double>[
        for (var i = 0; i < 100; i++) i % 10 < 3 ? 360.0 : 180.0,
      ];
      final take = analyzeSaTake(samples)!;
      expect(take.medianHz, 180.0);
      expect(take.isStable, isTrue);
    });

    test('in-octave slide still reads unstable after folding', () {
      // A glide from 200 Hz up a fourth stays inside one octave; folding
      // must not rescue genuine unsteadiness.
      final samples = <double>[
        for (var i = 0; i < 50; i++) 200.0 + i * (67.0 / 49.0),
      ];
      final take = analyzeSaTake(samples)!;
      expect(take.isStable, isFalse);
    });

    test('vibrato-scale wobble is measured, not folded away', () {
      // +/-40c sine wobble: sub-octave, so folding changes nothing and the
      // spread (~28c RMS) still exceeds the 25c steadiness limit.
      final samples = <double>[
        for (var i = 0; i < 64; i++)
          freqFromCents(200.0, 40.0 * sin(2 * pi * i / 16)),
      ];
      final take = analyzeSaTake(samples)!;
      expect(take.stdDevCents, greaterThan(25.0));
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

    test('a whole-take octave lock does not fail the set', () {
      // Regression (device, 2026-10-21): three identical 233 Hz sine
      // takes; the tracker locked one a full octave down (116.67 Hz) and
      // the unfolded agreement gate rejected the set as 'different'.
      final result = calibrateSa([take(233.33), take(116.67), take(233.33)]);
      expect(result, isNotNull);
      expect(result!.saHz, closeTo(233.33, 0.5));
      expect(result.agreementCents, lessThan(15.0));
      expect(result.confidence, 'high');
    });

    test('an octave-up take folds into the set octave', () {
      final result = calibrateSa([take(220.0), take(440.0), take(220.0)]);
      expect(result, isNotNull);
      expect(result!.saHz, closeTo(220.0, 0.5));
    });

    test('in-octave disagreement still fails after folding', () {
      // 246.94 Hz is a whole tone above 220, not an octave: folding must
      // not manufacture agreement out of genuinely different pitches.
      final result = calibrateSa([take(220.0), take(220.0), take(246.94)]);
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

  group('known-key helpers (plan 3b)', () {
    test('hzForMidi matches A440 equal temperament', () {
      expect(hzForMidi(69), closeTo(440.0, 1e-9));
      expect(hzForMidi(56), closeTo(207.6523, 0.001)); // G#3
      expect(hzForMidi(58), closeTo(233.0819, 0.001)); // A#3
      expect(hzForMidi(44), closeTo(103.8262, 0.001)); // G#2
    });

    test('nearestMidiForHz finds the closest note', () {
      expect(nearestMidiForHz(207.65), equals(56));
      expect(nearestMidiForHz(233.33), equals(58)); // sine-probe value
      expect(nearestMidiForHz(227.32), equals(58)); // singer's measured Sa
      expect(nearestMidiForHz(116.67), equals(46)); // halved take -> A#2
    });

    test('note names use sharps and scientific octave', () {
      expect(noteNameForMidi(56), equals('G#3'));
      expect(noteNameForMidi(60), equals('C4'));
      expect(noteNameForMidi(69), equals('A4'));
      expect(noteNameForHz(207.65), equals('G#3'));
      expect(pitchClassNames[8], equals('G#'));
      expect(pitchClassNames.length, equals(12));
    });

    test('octave candidates center on the instance nearest 220 Hz', () {
      expect(candidateMidisForPitchClass(8), equals([44, 56, 68])); // G#
      expect(candidateMidisForPitchClass(0), equals([48, 60, 72])); // C
      expect(candidateMidisForPitchClass(11), equals([47, 59, 71])); // B
      // D# is the exact half-octave tie; the higher center wins.
      expect(candidateMidisForPitchClass(3), equals([51, 63, 75]));
    });

    test('every pitch class offers three singable candidates', () {
      for (var pc = 0; pc < 12; pc++) {
        final midis = candidateMidisForPitchClass(pc);
        expect(midis.length, equals(3));
        expect(midis[1] - midis[0], equals(12));
        expect(midis[2] - midis[1], equals(12));
        for (final m in midis) {
          expect(m % 12, equals(pc));
          final hz = hzForMidi(m);
          expect(hz, greaterThan(80.0));
          expect(hz, lessThan(650.0));
        }
      }
    });
  });
}
