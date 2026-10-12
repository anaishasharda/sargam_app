// Widget smoke test.
//
// The previous version of this file was the default Flutter template
// counter test: it pumped MyApp and expected a counter, which this app
// has never had, and it crashed because MyApp requires Firebase, which
// is not initialized in tests. It could never pass, so it trained
// everyone to ignore a red suite.
//
// This replaces it with a smoke test of a real app widget that needs no
// Firebase: the AudioCharacteristicsDisplay results panel, rendered with
// a fixed characteristics object. It catches build/layout crashes in
// the panel without depending on any backend.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sargam_app/feature/category/audio_characteristics_display.dart';
import 'package:sargam_app/models/audio_characteristics.dart';

void main() {
  testWidgets('AudioCharacteristicsDisplay renders the overview panel',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const characteristics = AudioCharacteristics(
      pitch: 220.0,
      tempo: 60.0,
      rhythm: [1.0, 0.5, 1.0, 0.5],
      notes: ['Sa', 'Re', 'Ga'],
      volume: 0.5,
      spectrum: [0.2, 0.5, 0.3, 0.1],
      duration: 5.0,
      pitchTrajectory: [220.0, 246.94, 261.63],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AudioCharacteristicsDisplay(
              userCharacteristics: characteristics,
            ),
          ),
        ),
      ),
    );
    // The panel runs a one-shot 1500 ms chart animation on init;
    // advance past it with a fixed pump rather than pumpAndSettle.
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(AudioCharacteristicsDisplay), findsOneWidget);
    expect(find.text('Audio Characteristics'), findsOneWidget);
    expect(find.text('Pitch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
