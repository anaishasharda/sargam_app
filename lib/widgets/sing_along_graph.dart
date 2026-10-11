import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/realtime_audio_service.dart';
import '../services/tone_synth_service.dart';

/// A scrolling pitch graph: orange target bars (TargetTrack) plus the user's
/// live pitch trace from the microphone. Time scrolls horizontally; the
/// playhead stays at ~30% from the left edge, mirroring the screenshot.
class SingAlongGraph extends StatefulWidget {
  final TargetTrack target;
  final Stream<RealtimeAudioData> liveStream;

  /// Stream of playback position seconds (e.g. from
  /// `just_audio`'s positionStream). If null, uses an internal timer
  /// starting at 0 — useful when there is no reference playback.
  final Stream<double>? playbackPositionSec;

  /// Visible window of time in seconds.
  final double windowSec;

  const SingAlongGraph({
    super.key,
    required this.target,
    required this.liveStream,
    this.playbackPositionSec,
    this.windowSec = 6.0,
  });

  @override
  State<SingAlongGraph> createState() => _SingAlongGraphState();
}

class _LiveSample {
  final double timeSec;
  final double freqHz;
  const _LiveSample(this.timeSec, this.freqHz);
}

class _SingAlongGraphState extends State<SingAlongGraph> {
  final List<_LiveSample> _live = [];
  StreamSubscription<RealtimeAudioData>? _liveSub;
  StreamSubscription<double>? _posSub;

  double _playheadSec = 0.0;
  Stopwatch? _fallbackClock;
  Timer? _fallbackTicker;

  static const int _maxLiveSamples = 600; // ~60s at 10 FPS

  @override
  void initState() {
    super.initState();
    _liveSub = widget.liveStream.listen(_onLive);

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

  void _onLive(RealtimeAudioData data) {
    if (!mounted) return;
    if (data.pitch <= 50 || data.pitch > 2000) return;
    _live.add(_LiveSample(_playheadSec, data.pitch));
    if (_live.length > _maxLiveSamples) {
      _live.removeRange(0, _live.length - _maxLiveSamples);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _posSub?.cancel();
    _fallbackTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 7,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B0E33),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            painter: _SingAlongPainter(
              target: widget.target,
              live: List.of(_live),
              playheadSec: _playheadSec,
              windowSec: widget.windowSec,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _SingAlongPainter extends CustomPainter {
  final TargetTrack target;
  final List<_LiveSample> live;
  final double playheadSec;
  final double windowSec;

  _SingAlongPainter({
    required this.target,
    required this.live,
    required this.playheadSec,
    required this.windowSec,
  });

  // Y-axis labels (with octave). Order = top→bottom, so high pitches at top.
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

  static const double _minSemitone = 0;
  static const double _maxSemitone = 12;

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxis = 36.0;
    const playheadFrac = 0.30;
    final plotRect = Rect.fromLTWH(
      leftAxis,
      8,
      size.width - leftAxis - 8,
      size.height - 16,
    );

    _drawGrid(canvas, plotRect);
    _drawTargets(canvas, plotRect);
    _drawLive(canvas, plotRect);
    _drawPlayhead(canvas, plotRect, playheadFrac);
  }

  // Y mapping: semitone → pixel within plotRect.
  double _yFor(double semitone, Rect r) {
    final clamped = semitone.clamp(_minSemitone, _maxSemitone);
    final t = (clamped - _minSemitone) / (_maxSemitone - _minSemitone);
    return r.bottom - t * r.height;
  }

  // X mapping: time-since-now to a pixel; playhead sits at playheadFrac.
  double _xFor(double timeSec, Rect r, double playheadFrac) {
    final dt = timeSec - playheadSec;
    final px = r.left + r.width * playheadFrac + (dt / windowSec) * r.width;
    return px;
  }

  double _semitoneFromHz(double hz) {
    if (hz <= 0) return 0;
    double semi = 12 * (math.log(hz / target.baseSaHz) / math.ln2);
    
    // Map the pitch to the closest octave matching the target display range.
    // This allows singers of any octave (e.g., lower male voices) to see their pitch
    // visually aligned with the target notes on the graph.
    while (semi < -4) {
      semi += 12;
    }
    while (semi > 16) {
      semi -= 12;
    }
    
    return semi;
  }

  void _drawGrid(Canvas canvas, Rect r) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.55),
      fontSize: 11,
    );

    final targetSemitones = target.notes.map((n) => n.semitones).toSet();

    for (final entry in _yLabels) {
      final y = _yFor(entry.semitones.toDouble(), r);
      
      final isTargetNote = targetSemitones.contains(entry.semitones);
      
      if (isTargetNote) {
        final highlightPaint = Paint()
          ..color = const Color(0xFFFFB347).withValues(alpha: 0.15)
          ..strokeWidth = 2;
        canvas.drawLine(Offset(r.left, y), Offset(r.right, y), highlightPaint);
      } else {
        canvas.drawLine(Offset(r.left, y), Offset(r.right, y), gridPaint);
      }

      textPainter.text = TextSpan(
        text: entry.label,
        style: isTargetNote
            ? labelStyle.copyWith(
                color: const Color(0xFFFFB347).withValues(alpha: 0.9),
                fontWeight: FontWeight.bold,
              )
            : labelStyle,
      );
      textPainter.layout(maxWidth: r.left - 4);
      textPainter.paint(
        canvas,
        Offset(r.left - textPainter.width - 4, y - textPainter.height / 2),
      );
    }
  }

  void _drawTargets(Canvas canvas, Rect r) {
    final paint = Paint()
      ..color = const Color(0xFFFFB347)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    const playheadFrac = 0.30;
    for (final note in target.notes) {
      final x1 = _xFor(note.startSec, r, playheadFrac);
      final x2 = _xFor(note.endSec, r, playheadFrac);
      if (x2 < r.left || x1 > r.right) continue;
      final y = _yFor(note.semitones.toDouble(), r);
      canvas.drawLine(
        Offset(math.max(x1, r.left - 4), y),
        Offset(math.min(x2, r.right + 4), y),
        paint,
      );
    }
  }

  void _drawLive(Canvas canvas, Rect r) {
    if (live.isEmpty) return;
    const playheadFrac = 0.30;
    
    // 1. Collect valid points
    final points = <Offset>[];
    for (final s in live) {
      final x = _xFor(s.timeSec, r, playheadFrac);
      if (x < r.left - 16 || x > r.right + 16) continue;
      final semi = _semitoneFromHz(s.freqHz);
      points.add(Offset(x, _yFor(semi, r)));
    }

    if (points.isEmpty) return;

    // Extend the last point to the exact playhead line to completely eliminate visual lag
    final lastSample = live.last;
    if (playheadSec - lastSample.timeSec < 0.15) {
      final currentX = r.left + r.width * playheadFrac;
      final semi = _semitoneFromHz(lastSample.freqHz);
      points.add(Offset(currentX, _yFor(semi, r)));
    }

    // 2. Treat all valid points as a single contiguous segment so it flows like a continuous wave
    final segments = <List<Offset>>[points];

    // 3. Setup paints for a smooth, glowing line
    final glowPaintOuter = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final glowPaintInner = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final mainPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 4. Smooth and draw each segment
    Offset? finalDotPosition;

    for (final seg in segments) {
      if (seg.length == 1) {
        canvas.drawCircle(seg.first, 2, Paint()..color = Colors.white);
        finalDotPosition = seg.first;
        continue;
      }

      // Exponential Moving Average (EMA) smoothing for zero visual lag and portamento across gaps
      final smoothed = <Offset>[];
      smoothed.add(seg.first);
      const double alpha = 0.4;
      for (int i = 1; i < seg.length; i++) {
        final prevY = smoothed[i - 1].dy;
        final currentY = seg[i].dy;
        final newY = alpha * currentY + (1 - alpha) * prevY;
        smoothed.add(Offset(seg[i].dx, newY));
      }

      // Build smooth path
      final path = Path();
      path.moveTo(smoothed.first.dx, smoothed.first.dy);
      
      if (smoothed.length == 2) {
        path.lineTo(smoothed.last.dx, smoothed.last.dy);
      } else {
        for (int i = 1; i < smoothed.length - 1; i++) {
          final p0 = smoothed[i];
          final p1 = smoothed[i + 1];
          path.quadraticBezierTo(
            p0.dx, p0.dy,
            (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2,
          );
        }
        path.lineTo(smoothed.last.dx, smoothed.last.dy);
      }

      canvas.drawPath(path, glowPaintOuter);
      canvas.drawPath(path, glowPaintInner);
      canvas.drawPath(path, mainPaint);
      
      finalDotPosition = smoothed.last;
    }

    // 5. Highlight current sample as an interactive glowing dot perfectly attached to the end of the line
    if (finalDotPosition != null) {
      final cx = finalDotPosition.dx;
      final cy = finalDotPosition.dy;
      
      if (cx >= r.left - 16 && cx <= r.right + 16) {
        canvas.drawCircle(
          Offset(cx, cy),
          12,
          Paint()
            ..color = Colors.cyanAccent.withValues(alpha: 0.2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(
          Offset(cx, cy),
          6,
          Paint()..color = Colors.cyanAccent.withValues(alpha: 0.8),
        );
        canvas.drawCircle(
          Offset(cx, cy),
          3,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  void _drawPlayhead(Canvas canvas, Rect r, double frac) {
    final x = r.left + r.width * frac;
    final paint = Paint()
      ..color = Colors.deepPurpleAccent.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), paint);
  }

  @override
  bool shouldRepaint(covariant _SingAlongPainter old) {
    return old.playheadSec != playheadSec ||
        old.live.length != live.length ||
        old.target != target;
  }
}
