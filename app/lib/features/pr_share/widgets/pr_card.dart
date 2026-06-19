import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/pr_card_data.dart';

/// Self-contained PR card widget rendered at [size]×[size].
///
/// Designed to be wrapped in a [RepaintBoundary] and captured with
/// [RenderRepaintBoundary.toImage] at [pixelRatio] 3.0 to produce a
/// 1080×1080 PNG (when [size] is 360).
class PrCard extends StatelessWidget {
  const PrCard({super.key, required this.data, this.size = 360});

  final PrCardData data;
  final double size;

  static const _gold = Color(0xFFFFB300);
  static const _dark = Color(0xFF121212);

  @override
  Widget build(BuildContext context) {
    final p = size * 0.075;

    return SizedBox(
      width: size,
      height: size,
      child: ColoredBox(
        color: _dark,
        child: Padding(
          padding: EdgeInsets.all(p),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo ───────────────────────────────────────────────────
              Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    color: _gold,
                    size: size * 0.065,
                  ),
                  SizedBox(width: size * 0.02),
                  Text(
                    'IronLog',
                    style: GoogleFonts.dmSans(
                      color: _gold,
                      fontSize: size * 0.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // ── Exercise name ──────────────────────────────────────────
              Text(
                data.exerciseName.toUpperCase(),
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: size * 0.048,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: size * 0.03),

              // ── Value ──────────────────────────────────────────────────
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _valueLabel(),
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: size * 0.17,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ),

              SizedBox(height: size * 0.025),

              // ── PR badge ───────────────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size * 0.03,
                  vertical: size * 0.012,
                ),
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _recordTypeLabel(),
                  style: GoogleFonts.dmSans(
                    color: Colors.black,
                    fontSize: size * 0.032,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const Spacer(),

              // ── Footer: est 1RM + RPE + athlete ───────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.estimatedOneRm != null)
                    Text(
                      'Est. 1RM  ${data.estimatedOneRm!.toStringAsFixed(1)} kg',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: size * 0.036,
                      ),
                    ),
                  if (data.rpe != null) ...[
                    SizedBox(height: size * 0.008),
                    Text(
                      'RPE ${_formatRpe(data.rpe!)}',
                      style: GoogleFonts.dmSans(
                        color: _gold.withValues(alpha: 0.85),
                        fontSize: size * 0.036,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (data.athleteName != null && data.athleteName!.isNotEmpty) ...[
                    SizedBox(height: size * 0.012),
                    Text(
                      data.athleteName!,
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: size * 0.032,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _valueLabel() => switch (data.recordType) {
        'max_weight' => '${_compact(data.value)} kg',
        'max_reps' => '${data.value.toInt()} reps',
        'max_volume' => _compact(data.value),
        'best_pace' => _pace(data.value),
        _ => data.value.toStringAsFixed(1),
      };

  String _recordTypeLabel() => switch (data.recordType) {
        'max_weight' => '★  NEW PR — MAX WEIGHT',
        'max_reps' => '★  NEW PR — MAX REPS',
        'max_volume' => '★  NEW PR — MAX VOLUME',
        'best_pace' => '★  NEW PR — BEST PACE',
        _ => '★  NEW PERSONAL RECORD',
      };

  String _compact(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  String _pace(double secPerKm) {
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).toInt().toString().padLeft(2, '0');
    return '$m:$s /km';
  }

  String _formatRpe(double rpe) =>
      rpe == rpe.truncateToDouble() ? rpe.toInt().toString() : rpe.toString();
}
