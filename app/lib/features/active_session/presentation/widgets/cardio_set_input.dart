import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Form for logging a single cardio interval/effort. Provides a stopwatch
/// timer (Start / Pause / Stop) that auto-populates the duration field, plus
/// manual distance, heart rate, and RPE inputs. Pace is calculated live.
class CardioSetInputRow extends StatefulWidget {
  const CardioSetInputRow({
    super.key,
    required this.setNumber,
    required this.onLog,
    this.previousDurationSec,
    this.previousDistanceM,
    this.targetDurationSec,
    this.targetDistanceM,
  });

  final int setNumber;
  final void Function({
    int? durationSec,
    double? distanceM,
    int? heartRate,
    int? rpe,
  }) onLog;

  /// Pre-fill hint from the previous session (shown as placeholder).
  final int? previousDurationSec;
  final double? previousDistanceM;

  /// Plan targets — displayed as header hint.
  final int? targetDurationSec;
  final double? targetDistanceM;

  @override
  State<CardioSetInputRow> createState() => _CardioSetInputRowState();
}

class _CardioSetInputRowState extends State<CardioSetInputRow>
    with SingleTickerProviderStateMixin {
  // ── Stopwatch timer ────────────────────────────────────────────────────────
  final Stopwatch _stopwatch = Stopwatch();
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  _TimerState _timerState = _TimerState.idle;

  // ── Text controllers ───────────────────────────────────────────────────────
  late final TextEditingController _durationCtrl;
  late final TextEditingController _distanceCtrl;
  final TextEditingController _heartRateCtrl = TextEditingController();
  final TextEditingController _rpeCtrl = TextEditingController();

  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);

    _durationCtrl = TextEditingController(
      text: widget.previousDurationSec != null
          ? _formatDurationField(widget.previousDurationSec!)
          : '',
    );
    _distanceCtrl = TextEditingController(
      text: widget.previousDistanceM != null
          ? (widget.previousDistanceM! / 1000).toStringAsFixed(2)
          : '',
    );

    _durationCtrl.addListener(_onFieldChanged);
    _distanceCtrl.addListener(_onFieldChanged);
  }

  // Fix #1: stop ticker before disposing — Ticker.dispose() asserts it is
  // inactive, so calling dispose() while it is still ticking throws a
  // FlutterError in debug and causes undefined behaviour in release.
  @override
  void dispose() {
    _ticker.stop();
    _stopwatch.stop();
    _ticker.dispose();
    _durationCtrl.removeListener(_onFieldChanged);
    _distanceCtrl.removeListener(_onFieldChanged);
    _durationCtrl.dispose();
    _distanceCtrl.dispose();
    _heartRateCtrl.dispose();
    _rpeCtrl.dispose();
    super.dispose();
  }

  // Fix #5: reset timer when the parent rebuilds with a new set number (e.g.
  // after a set is deleted and numbers shift). Refresh pre-fill values only
  // when the text field is still empty so manual input is never clobbered.
  @override
  void didUpdateWidget(CardioSetInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.setNumber != oldWidget.setNumber) {
      _resetTimer();
    }
    if (widget.previousDurationSec != oldWidget.previousDurationSec &&
        _durationCtrl.text.isEmpty) {
      _durationCtrl.text = widget.previousDurationSec != null
          ? _formatDurationField(widget.previousDurationSec!)
          : '';
    }
    if (widget.previousDistanceM != oldWidget.previousDistanceM &&
        _distanceCtrl.text.isEmpty) {
      _distanceCtrl.text = widget.previousDistanceM != null
          ? (widget.previousDistanceM! / 1000).toStringAsFixed(2)
          : '';
    }
  }

  // ── Ticker callback ────────────────────────────────────────────────────────

  void _onTick(Duration _) {
    setState(() {
      _elapsed = _stopwatch.elapsed;
    });
  }

  void _onFieldChanged() => setState(() {});

  // ── Timer controls ─────────────────────────────────────────────────────────

  void _startTimer() {
    _stopwatch.start();
    _ticker.start();
    setState(() => _timerState = _TimerState.running);
  }

  void _pauseTimer() {
    _stopwatch.stop();
    _ticker.stop();
    setState(() => _timerState = _TimerState.paused);
  }

  void _stopTimer() {
    _stopwatch.stop();
    _ticker.stop();
    // Populate the duration field with elapsed time.
    final secs = _stopwatch.elapsed.inSeconds;
    _durationCtrl.text = _formatDurationField(secs);
    setState(() {
      _elapsed = _stopwatch.elapsed;
      _timerState = _TimerState.stopped;
    });
  }

  void _resetTimer() {
    _stopwatch
      ..stop()
      ..reset();
    _ticker.stop();
    setState(() {
      _elapsed = Duration.zero;
      _timerState = _TimerState.idle;
    });
  }

  // ── Pace calculation ───────────────────────────────────────────────────────

  /// Parses mm:ss duration field. Returns null if invalid.
  int? _parseDurationSec(String text) {
    final parts = text.trim().split(':');
    if (parts.length == 2) {
      final mins = int.tryParse(parts[0]);
      final secs = int.tryParse(parts[1]);
      if (mins != null && secs != null && secs < 60) {
        return mins * 60 + secs;
      }
    }
    // Allow plain integer seconds too (e.g. "3600").
    return int.tryParse(text.trim());
  }

  String? _paceLabel() {
    final durationSec = _parseDurationSec(_durationCtrl.text);
    final distanceKm = double.tryParse(_distanceCtrl.text.trim());
    if (durationSec == null || distanceKm == null || distanceKm <= 0) {
      return null;
    }
    // Fix #2: use the same formula as ActiveSessionNotifier.logSet so the
    // live display and the stored paceSecPerKm are computed identically.
    // distanceM = distanceKm * 1000; paceSecPerKm = durationSec / (distanceM / 1000)
    // simplifies to durationSec / distanceKm, but written this way the coupling
    // is explicit and a future refactor to either side will be obvious.
    final distanceM = distanceKm * 1000;
    final paceSecPerKm = durationSec / (distanceM / 1000);
    final paceMin = paceSecPerKm ~/ 60;
    final paceSec = (paceSecPerKm % 60).round();
    return '$paceMin:${paceSec.toString().padLeft(2, '0')} /km';
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  void _submit() {
    final durationSec = _parseDurationSec(_durationCtrl.text);
    final distanceKm = double.tryParse(_distanceCtrl.text.trim());
    final distanceM = distanceKm != null ? distanceKm * 1000 : null;

    // Fix #3: require at least duration or distance — an entirely empty set
    // would produce a row with no meaningful data.
    if (durationSec == null && distanceM == null) return;

    // Fix #4: clamp optional fields to physiologically valid ranges.
    // Values outside these ranges are almost certainly mis-keys; silently
    // dropping them is safer than storing garbage that could permanently break
    // server-side sync if validation is tightened later.
    final hrRaw = int.tryParse(_heartRateCtrl.text.trim());
    final heartRate =
        (hrRaw != null && hrRaw >= 30 && hrRaw <= 250) ? hrRaw : null;

    final rpeRaw = int.tryParse(_rpeCtrl.text.trim());
    final rpe = (rpeRaw != null && rpeRaw >= 1 && rpeRaw <= 10) ? rpeRaw : null;

    widget.onLog(
      durationSec: durationSec,
      distanceM: distanceM,
      heartRate: heartRate,
      rpe: rpe,
    );

    // Reset timer and fields.
    _resetTimer();
    _durationCtrl.clear();
    _distanceCtrl.clear();
    _heartRateCtrl.clear();
    _rpeCtrl.clear();
    setState(() => _showAdvanced = false);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDurationField(int totalSec) {
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatElapsed(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pace = _paceLabel();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row (set number + timer) ───────────────────────────
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.setNumber}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Timer display
                Text(
                  _formatElapsed(_elapsed),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: [const FontFeature.tabularFigures()],
                    color: _timerState == _TimerState.running
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                _TimerControls(
                  state: _timerState,
                  onStart: _startTimer,
                  onPause: _pauseTimer,
                  onResume: _startTimer,
                  onStop: _stopTimer,
                  onReset: _resetTimer,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Duration + Distance row ───────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Duration',
                      hintText: 'mm:ss',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: _timerState == _TimerState.running
                          ? const Icon(Icons.timer, size: 16)
                          : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _distanceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Distance',
                      hintText: 'km',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _submit,
                  icon: const Icon(Icons.check),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            // ── Live pace display ─────────────────────────────────────────
            if (pace != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.speed, size: 14,
                        color: theme.colorScheme.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      pace,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Advanced fields (HR + RPE) ────────────────────────────────
            if (_showAdvanced) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _heartRateCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Heart rate',
                        hintText: 'bpm',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _rpeCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'RPE (1-10)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],

            TextButton.icon(
              onPressed: () =>
                  setState(() => _showAdvanced = !_showAdvanced),
              icon: Icon(
                _showAdvanced ? Icons.expand_less : Icons.expand_more,
                size: 16,
              ),
              label: Text(_showAdvanced ? 'Hide options' : 'Heart rate / RPE'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timer state enum
// ---------------------------------------------------------------------------

enum _TimerState { idle, running, paused, stopped }

// ---------------------------------------------------------------------------
// Timer control buttons
// ---------------------------------------------------------------------------

class _TimerControls extends StatelessWidget {
  const _TimerControls({
    required this.state,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onReset,
  });

  final _TimerState state;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _TimerState.idle:
        return IconButton.outlined(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow),
          tooltip: 'Start timer',
          iconSize: 20,
          visualDensity: VisualDensity.compact,
        );

      case _TimerState.running:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.outlined(
              onPressed: onPause,
              icon: const Icon(Icons.pause),
              tooltip: 'Pause',
              iconSize: 20,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              onPressed: onStop,
              icon: const Icon(Icons.stop),
              tooltip: 'Stop & use time',
              iconSize: 20,
              visualDensity: VisualDensity.compact,
            ),
          ],
        );

      case _TimerState.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.outlined(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Resume',
              iconSize: 20,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              onPressed: onStop,
              icon: const Icon(Icons.stop),
              tooltip: 'Stop & use time',
              iconSize: 20,
              visualDensity: VisualDensity.compact,
            ),
          ],
        );

      case _TimerState.stopped:
        return IconButton.outlined(
          onPressed: onReset,
          icon: const Icon(Icons.refresh),
          tooltip: 'Reset timer',
          iconSize: 20,
          visualDensity: VisualDensity.compact,
        );
    }
  }
}
