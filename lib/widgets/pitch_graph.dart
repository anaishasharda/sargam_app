import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/realtime_audio_service.dart';
import '../services/tone_synth_service.dart';

/// A real-time pitch/frequency graph that shows the user's voice as a smooth
/// Bezier curve overlaid on the target sargam notes. The Y-axis shows note
/// labels (Sa, Re, Ga, Ma, Pa, Dha, Ni, Sa') and the X-axis scrolls with
/// time. Target notes appear as glowing orange bars; the user's pitch appears
/// as a smooth cyan curve with glow and an animated dot at the playhead.
///
/// Also shows a subtle amplitude "fill" beneath the pitch line so the user
/// can see they are being heard even when pitch is uncertain.
class PitchGraph extends StatefulWidget {
  final TargetTrack target;
  final Stream<RealtimeAudioData> liveStream;
  final Stream<List<double>> waveformStream;

  /// Stream of playback position seconds. If null, uses an internal timer.
  final Stream<double>? playbackPositionSec;

  /// Visible window of time in seconds.
  final double windowSec;

  const PitchGraph({
    super.key,
    required this.target,
    required this.liveStream,
    required this.waveformStream,
    this.playbackPositionSec,
    this.windowSec = 6.0,
  });

  @override
  State<PitchGraph> createState() => _PitchGraphState();
}

/// A single pitch sample with time, frequency, and volume.
class _PitchSample {
  final double timeSec;
  final double freqHz;
  final double volume; // 0..1 RMS
  const _PitchSample(this.timeSec, this.freqHz, this.volume);
}

class _PitchGraphState extends State<PitchGraph>
    with SingleTickerProviderStateMixin {
  final List<_PitchSample> _samples = [];
  StreamSubscription<RealtimeAudioData>? _liveSub;
  StreamSubscription<List<double>>? _waveSub;
  StreamSubscription<double>? _posSub;

  double _playheadSec = 0.0;
  Stopwatch? _fallbackClock;
  Timer? _fallbackTicker;

  // Current volume level from the waveform stream (for the amplitude glow)
  double _currentVolume = 0.0;

  // Animation controller for the breathing dot
  late AnimationController _dotPulse;

  static const int _maxSamples = 1200; // ~2 min at 10 FPS

  @override
  void initState() {
    super.initState();

    _dotPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _liveSub = widget.liveStream.listen(_onLiveData);
    _waveSub = widget.waveformStream.listen(_onWaveform);

    if (widget.playbackPositionSec != null) {
      _posSub = widget.playbackPositionSec!.listen((sec) {
        if (!mounted) return;
        setState(() => _playheadSec = sec);
      });
    } else {
      _fallbackClock = Stopwatch()..start();
      _fallbackTicker = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!mounted) return;
        setState(() => _playheadSec =
            (_fallbackClock?.elapsedMilliseconds ?? 0) / 1000.0);
      });
    }
  }

  void _onLiveData(RealtimeAudioData data) {
    if (!mounted) return;

    // Accept ANY pitch > 0 — we handle filtering/clamping in the painter.
    // Also store volume so we can draw amplitude even when pitch = 0.
    _samples.add(_PitchSample(_playheadSec, data.pitch, data.volume));

    if (_samples.length > _maxSamples) {
      _samples.removeRange(0, _samples.length - _maxSamples);
    }
    setState(() {});
  }

  void _onWaveform(List<double> samples) {
    if (!mounted || samples.isEmpty) return;
    // Calculate peak amplitude for this chunk
    double peak = 0;
    for (final s in samples) {
      final a = s.abs();
      if (a > peak) peak = a;
    }
    _currentVolume = peak.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _waveSub?.cancel();
    _posSub?.cancel();
    _fallbackTicker?.cancel();
    _dotPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 7,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF110A22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurpleAccent.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AnimatedBuilder(
            animation: _dotPulse,
            builder: (context, _) {
              return CustomPaint(
                painter: _PitchGraphPainter(
                  target: widget.target,
                  samples: List.of(_samples),
                  playheadSec: _playheadSec,
                  windowSec: widget.windowSec,
                  currentVolume: _currentVolume,
                  dotPulse: _dotPulse.value,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painter for the pitch graph
// ─────────────────────────────────────────────────────────────────────────────

class _PitchGraphPainter extends CustomPainter {
  final TargetTrack target;
  final List<_PitchSample> samples;
  final double playheadSec;
  final double windowSec;
  final double currentVolume;
  final double dotPulse; // 0..1 animation value

  _PitchGraphPainter({
    required this.target,
    required this.samples,
    required this.playheadSec,
    required this.windowSec,
    required this.currentVolume,
    required this.dotPulse,
  });

  // ── Y-axis: note labels. Order = top → bottom (high → low pitch).
  static const List<({String label, int semitones})> _yLabels = [
    (label: "Sa'", semitones: 12),
    (label: 'Ni', semitones: 11),
    (label: 'Dha', semitones: 9),
    (label: 'Pa', semitones: 7),
    (label: 'Ma', semitones: 5),
    (label: 'Ga', semitones: 4),
    (label: 'Re', semitones: 2),
    (label: 'Sa', semitones: 0),
  ];

  static const double _minSemi = -1; // a little below Sa
  static const double _maxSemi = 13; // a little above Sa'

  static const double _leftAxis = 40.0;
  static const double _topPad = 10.0;
  static const double _bottomPad = 10.0;
  static const double _rightPad = 10.0;
  static const double _playheadFrac = 0.30;

  Rect _plotRect(Size size) => Rect.fromLTWH(
        _leftAxis,
        _topPad,
        size.width - _leftAxis - _rightPad,
        size.height - _topPad - _bottomPad,
      );

  // ── Coordinate helpers ──

  double _yFor(double semitone, Rect r) {
    final clamped = semitone.clamp(_minSemi, _maxSemi);
    final t = (clamped - _minSemi) / (_maxSemi - _minSemi);
    return r.bottom - t * r.height;
  }

  double _xFor(double timeSec, Rect r) {
    final dt = timeSec - playheadSec;
    return r.left + r.width * _playheadFrac + (dt / windowSec) * r.width;
  }

  double _semitoneFromHz(double hz) {
    if (hz <= 0) return -999;
    double semi = 12 * (math.log(hz / target.baseSaHz) / math.ln2);
    // Fold into the visible octave range so any singer registers on-screen
    while (semi < -4) semi += 12;
    while (semi > 16) semi -= 12;
    return semi;
  }

  // ── Paint ──

  @override
  void paint(Canvas canvas, Size size) {
    final r = _plotRect(size);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    _drawBackground(canvas, r, size);
    _drawGrid(canvas, r);
    _drawTargetBars(canvas, r);
    _drawVoiceWaveform(canvas, r);
    _drawAmplitudeGlow(canvas, r);
    _drawPitchCurve(canvas, r);
    _drawPlayhead(canvas, r, size);
    _drawVoiceLabel(canvas, r);

    canvas.restore();
  }

  // ── 1. Background gradient ──
  void _drawBackground(Canvas canvas, Rect r, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF160D2E),
          const Color(0xFF0D0718),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      bgPaint,
    );
  }

  // ── 2. Grid lines + note labels ──
  void _drawGrid(Canvas canvas, Rect r) {
    final targetSemitones = target.notes.map((n) => n.semitones).toSet();
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final entry in _yLabels) {
      final y = _yFor(entry.semitones.toDouble(), r);
      final isTarget = targetSemitones.contains(entry.semitones);

      // Horizontal grid line
      final linePaint = Paint()
        ..strokeWidth = isTarget ? 1.2 : 0.5
        ..color = isTarget
            ? const Color(0xFFFFB347).withOpacity(0.20)
            : Colors.white.withOpacity(0.05);
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), linePaint);

      // Note label
      textPainter.text = TextSpan(
        text: entry.label,
        style: TextStyle(
          color: isTarget
              ? const Color(0xFFFFB347).withOpacity(0.95)
              : Colors.white.withOpacity(0.40),
          fontSize: 11,
          fontWeight: isTarget ? FontWeight.w700 : FontWeight.w400,
          letterSpacing: 0.3,
        ),
      );
      textPainter.layout(maxWidth: _leftAxis - 6);
      textPainter.paint(
        canvas,
        Offset(r.left - textPainter.width - 5, y - textPainter.height / 2),
      );
    }
  }

  // ── 3. Target note bars (orange) ──
  void _drawTargetBars(Canvas canvas, Rect r) {
    final barPaint = Paint()
      ..color = const Color(0xFFFFB347)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7;

    final glowPaint = Paint()
      ..color = const Color(0xFFFFB347).withOpacity(0.15)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (final note in target.notes) {
      final x1 = _xFor(note.startSec, r);
      final x2 = _xFor(note.endSec, r);
      if (x2 < r.left - 20 || x1 > r.right + 20) continue;
      final y = _yFor(note.semitones.toDouble(), r);

      final clampedX1 = math.max(x1, r.left - 4);
      final clampedX2 = math.min(x2, r.right + 4);

      // Glow
      canvas.drawLine(Offset(clampedX1, y), Offset(clampedX2, y), glowPaint);
      // Core
      canvas.drawLine(Offset(clampedX1, y), Offset(clampedX2, y), barPaint);

      // Note label on the bar (for bars currently near the playhead)
      final barMidX = (clampedX1 + clampedX2) / 2;
      if (barMidX > r.left + 20 && barMidX < r.right - 20) {
        final tp = TextPainter(
          text: TextSpan(
            text: note.sargam,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(barMidX - tp.width / 2, y - 16));
      }
    }
  }

  // ── 4. Amplitude glow band at the playhead ──
  void _drawAmplitudeGlow(Canvas canvas, Rect r) {
    if (currentVolume < 0.003) return;

    final cx = r.left + r.width * _playheadFrac;
    final amp = math.pow(currentVolume.clamp(0.0, 1.0), 0.4).toDouble();
    final radius = 12.0 + amp * 60.0;

    // Bright radial glow
    final gradient = RadialGradient(
      colors: [
        Colors.cyanAccent.withOpacity(0.25 * amp),
        Colors.cyanAccent.withOpacity(0.08 * amp),
        Colors.cyanAccent.withOpacity(0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    canvas.drawCircle(
      Offset(cx, r.center.dy),
      radius,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: Offset(cx, r.center.dy), radius: radius),
        ),
    );
  }

  // ── 4b. Waveform bars along the bottom of the graph ──
  void _drawVoiceWaveform(Canvas canvas, Rect r) {
    if (samples.isEmpty) return;

    // Draw amplitude bars in the bottom quarter of the graph
    final waveH = r.height * 0.18;
    final baseY = r.bottom - 2;

    final barPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    final glowBarPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (final s in samples) {
      final x = _xFor(s.timeSec, r);
      if (x < r.left - 5 || x > r.right + 5) continue;

      final vol = s.volume.clamp(0.0, 1.0);
      if (vol < 0.003) continue;

      // Compress volume for better visual range
      final amp = math.pow(vol, 0.45).toDouble();
      final barH = amp * waveH;

      // Color intensity based on volume
      final opacity = 0.3 + 0.7 * amp;

      glowBarPaint.color = Colors.cyanAccent.withOpacity(0.2 * opacity);
      barPaint.color = Colors.cyanAccent.withOpacity(opacity);

      canvas.drawLine(
        Offset(x, baseY),
        Offset(x, baseY - barH),
        glowBarPaint,
      );
      canvas.drawLine(
        Offset(x, baseY),
        Offset(x, baseY - barH),
        barPaint,
      );
    }
  }

  // ── 5. User pitch curve (the main feature) ──
  void _drawPitchCurve(Canvas canvas, Rect r) {
    if (samples.isEmpty) return;

    // Collect all plottable points (with valid pitch)
    final pitchPoints = <Offset>[];
    // Collect ALL points for volume envelope
    final volumePoints = <({double x, double vol})>[];

    for (final s in samples) {
      final x = _xFor(s.timeSec, r);
      if (x < r.left - 20 || x > r.right + 20) continue;

      volumePoints.add((x: x, vol: s.volume));

      if (s.freqHz > 50 && s.freqHz < 2000) {
        final semi = _semitoneFromHz(s.freqHz);
        if (semi > _minSemi - 2 && semi < _maxSemi + 2) {
          pitchPoints.add(Offset(x, _yFor(semi, r)));
        }
      }
    }

    // ─ Volume envelope (subtle fill under the center to show voice activity)
    _drawVolumeEnvelope(canvas, r, volumePoints);

    // ─ Pitch curve
    if (pitchPoints.length >= 2) {
      // Smooth points with EMA
      final smoothed = _emaSmooth(pitchPoints, 0.35);

      // Extend to playhead if recent
      final lastSample = samples.last;
      if (lastSample.freqHz > 50 &&
          lastSample.freqHz < 2000 &&
          playheadSec - lastSample.timeSec < 0.15) {
        final cx = r.left + r.width * _playheadFrac;
        final semi = _semitoneFromHz(lastSample.freqHz);
        smoothed.add(Offset(cx, _yFor(semi, r)));
      }

      // Build Bezier path
      final path = _buildSmoothPath(smoothed);

      // 3-layer glow: outer → inner → core
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.cyanAccent.withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.cyanAccent.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );

      // ─ Animated dot at the end of the pitch curve
      _drawPitchDot(canvas, smoothed.last, r);
    } else if (pitchPoints.length == 1) {
      _drawPitchDot(canvas, pitchPoints.first, r);
    }
  }

  void _drawVolumeEnvelope(
      Canvas canvas, Rect r, List<({double x, double vol})> points) {
    if (points.length < 2) return;

    final mid = r.center.dy;
    final maxH = r.height * 0.30;

    final path = Path();
    path.moveTo(points.first.x, mid);

    // Top edge
    for (final p in points) {
      final amp = math.pow(p.vol.clamp(0.0, 1.0), 0.45) * maxH;
      path.lineTo(p.x, mid - amp);
    }

    // Bottom edge (reversed)
    for (int i = points.length - 1; i >= 0; i--) {
      final amp = math.pow(points[i].vol.clamp(0.0, 1.0), 0.45) * maxH;
      path.lineTo(points[i].x, mid + amp);
    }

    path.close();

    // Fill with a visible gradient
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.cyanAccent.withOpacity(0.08)
        ..style = PaintingStyle.fill,
    );

    // Outline
    // Top outline
    final topPath = Path();
    topPath.moveTo(points.first.x, mid);
    for (final p in points) {
      final amp = math.pow(p.vol.clamp(0.0, 1.0), 0.45) * maxH;
      topPath.lineTo(p.x, mid - amp);
    }
    canvas.drawPath(
      topPath,
      Paint()
        ..color = Colors.cyanAccent.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  // ── Voice label ──
  void _drawVoiceLabel(Canvas canvas, Rect r) {
    if (currentVolume < 0.003) return;

    final tp = TextPainter(
      text: TextSpan(
        text: '🎤',
        style: TextStyle(
          fontSize: 12,
          color: Colors.cyanAccent.withOpacity(0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(r.right - tp.width - 4, r.bottom - tp.height - 4));
  }

  void _drawPitchDot(Canvas canvas, Offset pos, Rect r) {
    if (pos.dx < r.left - 10 || pos.dx > r.right + 10) return;

    final pulse = 0.85 + 0.15 * dotPulse;

    // Outer glow
    canvas.drawCircle(
      pos,
      14 * pulse,
      Paint()
        ..color = Colors.cyanAccent.withOpacity(0.15 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Middle ring
    canvas.drawCircle(
      pos,
      7 * pulse,
      Paint()..color = Colors.cyanAccent.withOpacity(0.7),
    );

    // Core dot
    canvas.drawCircle(
      pos,
      3.5,
      Paint()..color = Colors.white,
    );
  }

  // ── 6. Playhead line ──
  void _drawPlayhead(Canvas canvas, Rect r, Size size) {
    final x = r.left + r.width * _playheadFrac;

    // Subtle vertical gradient line
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.deepPurpleAccent.withOpacity(0.0),
          Colors.deepPurpleAccent.withOpacity(0.5),
          Colors.deepPurpleAccent.withOpacity(0.5),
          Colors.deepPurpleAccent.withOpacity(0.0),
        ],
        stops: const [0.0, 0.15, 0.85, 1.0],
      ).createShader(Rect.fromLTRB(x, r.top, x + 1, r.bottom))
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), paint);
  }

  // ── Helpers ──

  List<Offset> _emaSmooth(List<Offset> points, double alpha) {
    if (points.isEmpty) return [];
    final smoothed = <Offset>[points.first];
    for (int i = 1; i < points.length; i++) {
      final prevY = smoothed[i - 1].dy;
      final newY = alpha * points[i].dy + (1 - alpha) * prevY;
      smoothed.add(Offset(points[i].dx, newY));
    }
    return smoothed;
  }

  Path _buildSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);

    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    // Catmull-Rom → Cubic Bezier for silky curves
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant _PitchGraphPainter old) {
    return old.playheadSec != playheadSec ||
        old.samples.length != samples.length ||
        old.currentVolume != currentVolume ||
        old.dotPulse != dotPulse ||
        old.target != target;
  }
}
