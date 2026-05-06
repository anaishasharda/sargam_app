import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compact live waveform of the user's mic input. Subscribes to a stream of
/// raw audio samples (range ~[-1, 1]) and renders a scrolling amplitude
/// waveform so the singer can see their own voice being captured in real
/// time, separate from the pitch graph above it.
class UserVoiceWaveform extends StatefulWidget {
  /// Stream of audio sample windows (Float32-style values in [-1, 1]) from
  /// the realtime audio service's waveform stream.
  final Stream<List<double>> waveformStream;

  /// Stream of detected pitch in Hz for the live readout label. Optional —
  /// pass null to hide the pitch label.
  final Stream<double>? pitchHzStream;

  /// Height of the waveform area in logical pixels.
  final double height;

  const UserVoiceWaveform({
    super.key,
    required this.waveformStream,
    this.pitchHzStream,
    this.height = 80,
  });

  @override
  State<UserVoiceWaveform> createState() => _UserVoiceWaveformState();
}

class _UserVoiceWaveformState extends State<UserVoiceWaveform> {
  // Compact amplitude history: each entry is the peak |sample| of one chunk.
  // We keep enough bars to fill the width comfortably and scroll as new data
  // arrives.
  final List<double> _bars = [];
  static const int _maxBars = 120;

  StreamSubscription<List<double>>? _waveSub;
  StreamSubscription<double>? _pitchSub;
  double _pitchHz = 0;

  @override
  void initState() {
    super.initState();
    _waveSub = widget.waveformStream.listen(_onWindow);
    _pitchSub = widget.pitchHzStream?.listen((hz) {
      if (!mounted) return;
      setState(() => _pitchHz = hz);
    });
  }

  @override
  void dispose() {
    _waveSub?.cancel();
    _pitchSub?.cancel();
    super.dispose();
  }

  void _onWindow(List<double> samples) {
    if (samples.isEmpty || !mounted) return;
    // Reduce each window to ~8 amplitude bars so we get smooth scrolling
    // without redrawing the whole waveform on every chunk.
    const barsPerWindow = 8;
    final step = math.max(1, samples.length ~/ barsPerWindow);
    for (int i = 0; i < samples.length; i += step) {
      final end = math.min(samples.length, i + step);
      double peak = 0;
      for (int j = i; j < end; j++) {
        final a = samples[j].abs();
        if (a > peak) peak = a;
      }
      _bars.add(peak);
    }
    if (_bars.length > _maxBars) {
      _bars.removeRange(0, _bars.length - _maxBars);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF1B0E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              size: Size.infinite,
              painter: _WaveformPainter(bars: List.of(_bars)),
            ),
          ),
          Positioned(
            top: 6,
            left: 10,
            child: Row(
              children: [
                const Icon(Icons.mic, color: Colors.cyanAccent, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Your voice',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (widget.pitchHzStream != null)
            Positioned(
              top: 6,
              right: 10,
              child: Text(
                _pitchHz > 50 && _pitchHz < 2000
                    ? '${_pitchHz.toStringAsFixed(0)} Hz'
                    : '—',
                style: TextStyle(
                  color: Colors.cyanAccent.withOpacity(0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> bars;

  _WaveformPainter({required this.bars});

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    const horizontalPad = 8.0;
    const topPad = 22.0; // leave room for the labels above
    const bottomPad = 8.0;
    final mid = (size.height + topPad - bottomPad) / 2 + 2;
    final usable = size.width - horizontalPad * 2;
    final maxBarHeight = (size.height - topPad - bottomPad) / 2;
    final barWidth = usable / _UserVoiceWaveformState._maxBars;

    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.35)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.5, barWidth * 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final mainPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.0, barWidth * 0.55);

    // Right-align the bars so the most recent sample sits at the right edge
    // and the waveform appears to scroll leftward.
    final startIndex = _UserVoiceWaveformState._maxBars - bars.length;
    for (int i = 0; i < bars.length; i++) {
      // Mild compression so quiet voices are still visible.
      final amp = math.pow(bars[i].clamp(0.0, 1.0), 0.6).toDouble();
      final h = amp * maxBarHeight;
      final x = horizontalPad + (startIndex + i) * barWidth + barWidth / 2;
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), glowPaint);
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), mainPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.bars.length != bars.length ||
      (bars.isNotEmpty && old.bars.isNotEmpty && old.bars.last != bars.last);
}
