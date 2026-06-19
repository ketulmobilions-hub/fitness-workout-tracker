import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

part 'pr_share_provider.freezed.dart';
part 'pr_share_provider.g.dart';

@freezed
abstract class PrShareState with _$PrShareState {
  const factory PrShareState({
    @Default(false) bool isCapturing,
    @Default(false) bool savedSuccessfully,
    String? error,
  }) = _PrShareState;
}

@riverpod
class PrShare extends _$PrShare {
  @override
  PrShareState build() => const PrShareState();

  Future<Uint8List?> _capture(GlobalKey key) async {
    final obj = key.currentContext?.findRenderObject();
    if (obj is! RenderRepaintBoundary) return null;
    final image = await obj.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> captureAndShare(GlobalKey key) async {
    state = state.copyWith(isCapturing: true, error: null, savedSuccessfully: false);
    try {
      final bytes = await _capture(key);
      if (bytes == null) throw Exception('Could not render card');

      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/ironlog_pr_$ts.png');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'ironlog_pr.png')],
        text: 'New PR! 💪 #IronLog #Powerlifting',
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      state = state.copyWith(isCapturing: false);
    }
  }

  Future<void> captureAndSave(GlobalKey key) async {
    state = state.copyWith(isCapturing: true, error: null, savedSuccessfully: false);
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          state = state.copyWith(
            isCapturing: false,
            error: 'Photo library access denied',
          );
          return;
        }
      }

      final bytes = await _capture(key);
      if (bytes == null) throw Exception('Could not render card');

      final ts = DateTime.now().millisecondsSinceEpoch;
      await Gal.putImageBytes(bytes, name: 'ironlog_pr_$ts.png');

      state = state.copyWith(savedSuccessfully: true);
    } on GalException catch (e) {
      state = state.copyWith(
        error: switch (e.type) {
          GalExceptionType.notEnoughSpace => 'Not enough storage space',
          GalExceptionType.accessDenied => 'Photo library access denied',
          GalExceptionType.notSupportedFormat => 'Unsupported image format',
          _ => 'Could not save to Photos',
        },
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      state = state.copyWith(isCapturing: false);
    }
  }
}
