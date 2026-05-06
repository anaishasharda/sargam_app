/// A simple Alankar exercise: a sequence of sargam tokens to be sung in order
/// at a chosen tempo, repeating one motif as it climbs the scale and returns.
///
/// Token grammar (suddh-Bilawal scale only):
///   middle octave: Sa Re Ga Ma Pa Dha Ni
///   upper octave : Sa' Re' Ga' Ma'
///   lower octave : ,Pa ,Dha ,Ni
class Alankar {
  final String id;
  final String name;
  final String description;
  final List<String> pattern;

  const Alankar({
    required this.id,
    required this.name,
    required this.description,
    required this.pattern,
  });
}

/// 10 beginner-friendly alankars. Patterns are written ascending only;
/// the synth and graph automatically append the descending mirror so the
/// practice ends back at Sa.
const List<Alankar> kBeginnerAlankars = [
  Alankar(
    id: 'alankar_01',
    name: 'Alankar 1 — Pairs',
    description: 'Sa Re, Re Ga, Ga Ma, Ma Pa, Pa Dha, Dha Ni, Ni Sa\'',
    pattern: [
      'Sa', 'Re', 'Re', 'Ga', 'Ga', 'Ma', 'Ma', 'Pa',
      'Pa', 'Dha', 'Dha', 'Ni', 'Ni', "Sa'",
    ],
  ),
  Alankar(
    id: 'alankar_02',
    name: 'Alankar 2 — Triplets',
    description: 'Sa Re Ga, Re Ga Ma, Ga Ma Pa, Ma Pa Dha, Pa Dha Ni, Dha Ni Sa\'',
    pattern: [
      'Sa', 'Re', 'Ga',
      'Re', 'Ga', 'Ma',
      'Ga', 'Ma', 'Pa',
      'Ma', 'Pa', 'Dha',
      'Pa', 'Dha', 'Ni',
      'Dha', 'Ni', "Sa'",
    ],
  ),
  Alankar(
    id: 'alankar_03',
    name: 'Alankar 3 — Quartets',
    description: 'Sa Re Ga Ma, Re Ga Ma Pa, Ga Ma Pa Dha, Ma Pa Dha Ni, Pa Dha Ni Sa\'',
    pattern: [
      'Sa', 'Re', 'Ga', 'Ma',
      'Re', 'Ga', 'Ma', 'Pa',
      'Ga', 'Ma', 'Pa', 'Dha',
      'Ma', 'Pa', 'Dha', 'Ni',
      'Pa', 'Dha', 'Ni', "Sa'",
    ],
  ),
  Alankar(
    id: 'alankar_04',
    name: 'Alankar 4 — Skips',
    description: 'Sa Ga, Re Ma, Ga Pa, Ma Dha, Pa Ni, Dha Sa\'',
    pattern: [
      'Sa', 'Ga', 'Re', 'Ma', 'Ga', 'Pa',
      'Ma', 'Dha', 'Pa', 'Ni', 'Dha', "Sa'",
    ],
  ),
  Alankar(
    id: 'alankar_05',
    name: 'Alankar 5 — Turns',
    description: 'Sa Re Sa, Re Ga Re, Ga Ma Ga, Ma Pa Ma, Pa Dha Pa, Dha Ni Dha, Ni Sa\' Ni',
    pattern: [
      'Sa', 'Re', 'Sa',
      'Re', 'Ga', 'Re',
      'Ga', 'Ma', 'Ga',
      'Ma', 'Pa', 'Ma',
      'Pa', 'Dha', 'Pa',
      'Dha', 'Ni', 'Dha',
      'Ni', "Sa'", 'Ni',
    ],
  ),
  Alankar(
    id: 'alankar_06',
    name: 'Alankar 6 — Up-Down Motif',
    description: 'Sa Ga Re Sa, Re Ma Ga Re, Ga Pa Ma Ga, Ma Dha Pa Ma, Pa Ni Dha Pa, Dha Sa\' Ni Dha',
    pattern: [
      'Sa', 'Ga', 'Re', 'Sa',
      'Re', 'Ma', 'Ga', 'Re',
      'Ga', 'Pa', 'Ma', 'Ga',
      'Ma', 'Dha', 'Pa', 'Ma',
      'Pa', 'Ni', 'Dha', 'Pa',
      'Dha', "Sa'", 'Ni', 'Dha',
    ],
  ),
  Alankar(
    id: 'alankar_07',
    name: 'Alankar 7 — Returning Triplets',
    description: 'Sa Re Ga Re Sa, Re Ga Ma Ga Re, Ga Ma Pa Ma Ga, ...',
    pattern: [
      'Sa', 'Re', 'Ga', 'Re', 'Sa',
      'Re', 'Ga', 'Ma', 'Ga', 'Re',
      'Ga', 'Ma', 'Pa', 'Ma', 'Ga',
      'Ma', 'Pa', 'Dha', 'Pa', 'Ma',
      'Pa', 'Dha', 'Ni', 'Dha', 'Pa',
      'Dha', 'Ni', "Sa'", 'Ni', 'Dha',
    ],
  ),
  Alankar(
    id: 'alankar_08',
    name: 'Alankar 8 — Wave',
    description: 'Sa Re Ga Ma Ga Re Sa, Re Ga Ma Pa Ma Ga Re, ...',
    pattern: [
      'Sa', 'Re', 'Ga', 'Ma', 'Ga', 'Re', 'Sa',
      'Re', 'Ga', 'Ma', 'Pa', 'Ma', 'Ga', 'Re',
      'Ga', 'Ma', 'Pa', 'Dha', 'Pa', 'Ma', 'Ga',
      'Ma', 'Pa', 'Dha', 'Ni', 'Dha', 'Pa', 'Ma',
      'Pa', 'Dha', 'Ni', "Sa'", 'Ni', 'Dha', 'Pa',
    ],
  ),
  Alankar(
    id: 'alankar_09',
    name: 'Alankar 9 — Oscillation',
    description: 'Sa Re Sa Re Ga, Re Ga Re Ga Ma, ...',
    pattern: [
      'Sa', 'Re', 'Sa', 'Re', 'Ga',
      'Re', 'Ga', 'Re', 'Ga', 'Ma',
      'Ga', 'Ma', 'Ga', 'Ma', 'Pa',
      'Ma', 'Pa', 'Ma', 'Pa', 'Dha',
      'Pa', 'Dha', 'Pa', 'Dha', 'Ni',
      'Dha', 'Ni', 'Dha', 'Ni', "Sa'",
    ],
  ),
  Alankar(
    id: 'alankar_10',
    name: 'Alankar 10 — Pentads',
    description: 'Sa Re Ga Ma Pa, Re Ga Ma Pa Dha, Ga Ma Pa Dha Ni, Ma Pa Dha Ni Sa\'',
    pattern: [
      'Sa', 'Re', 'Ga', 'Ma', 'Pa',
      'Re', 'Ga', 'Ma', 'Pa', 'Dha',
      'Ga', 'Ma', 'Pa', 'Dha', 'Ni',
      'Ma', 'Pa', 'Dha', 'Ni', "Sa'",
    ],
  ),
];

/// Returns the full ascending+descending pattern by appending the reverse
/// of [ascending] (minus the last token to avoid a duplicated apex).
List<String> withDescendingMirror(List<String> ascending) {
  if (ascending.length < 2) return List.of(ascending);
  final descending = ascending.reversed.toList()..removeAt(0);
  return [...ascending, ...descending];
}
