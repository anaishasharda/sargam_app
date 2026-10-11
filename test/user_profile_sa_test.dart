import 'package:flutter_test/flutter_test.dart';
import 'package:sargam_app/models/user_profile.dart';

void main() {
  UserProfile base() => UserProfile(
        email: 'a@b.c',
        name: 'Test',
        joinedDate: DateTime(2026, 1, 1),
        lastPracticeDate: DateTime(2026, 1, 2),
      );

  group('Sa storage (Patch 3a)', () {
    test('round-trips Sa fields through Firestore map', () {
      final p = base().copyWith(
        baseSaHz: 138.59,
        saCalibratedAt: DateTime(2026, 10, 11, 9, 30),
        saConfidence: 'high',
      );
      final restored = UserProfile.fromFirestore(p.toFirestore(), 'uid1');
      expect(restored.baseSaHz, 138.59);
      expect(restored.saCalibratedAt, DateTime(2026, 10, 11, 9, 30));
      expect(restored.saConfidence, 'high');
    });

    test('legacy doc without Sa fields parses to nulls, no crash', () {
      final legacy = base().toFirestore()
        ..remove('baseSaHz')
        ..remove('saCalibratedAt')
        ..remove('saConfidence');
      final restored = UserProfile.fromFirestore(legacy, 'uid1');
      expect(restored.baseSaHz, isNull);
      expect(restored.saCalibratedAt, isNull);
      expect(restored.saConfidence, isNull);
    });

    test('uncalibrated profile serializes Sa fields as null', () {
      final map = base().toFirestore();
      expect(map['baseSaHz'], isNull);
      expect(map['saCalibratedAt'], isNull);
      expect(map['saConfidence'], isNull);
    });

    test('copyWith preserves Sa fields when not overridden', () {
      final p = base().copyWith(baseSaHz: 146.83, saConfidence: 'ok');
      final q = p.copyWith(totalSessions: 5);
      expect(q.baseSaHz, 146.83);
      expect(q.saConfidence, 'ok');
      expect(q.totalSessions, 5);
    });
  });
}
