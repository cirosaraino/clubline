import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ClubThemePaletteResult {
  const ClubThemePaletteResult({
    required this.primaryColor,
    required this.accentColor,
    required this.surfaceColor,
  });

  final Color primaryColor;
  final Color accentColor;
  final Color surfaceColor;

  String get primaryHex => _toHex(primaryColor);
  String get accentHex => _toHex(accentColor);
  String get surfaceHex => _toHex(surfaceColor);

  static String _toHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}

Future<ClubThemePaletteResult> extractClubThemePalette(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 48, targetHeight: 48);
  final frame = await codec.getNextFrame();
  final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    return _fallbackPalette();
  }

  final pixels = byteData.buffer.asUint8List();
  if (pixels.isEmpty) {
    return _fallbackPalette();
  }

  var redSum = 0.0;
  var greenSum = 0.0;
  var blueSum = 0.0;
  var sampleCount = 0.0;
  var brightest = const Color(0xFF2DD4BF);
  var highestScore = -1.0;

  for (var index = 0; index + 3 < pixels.length; index += 16) {
    final red = pixels[index].toDouble();
    final green = pixels[index + 1].toDouble();
    final blue = pixels[index + 2].toDouble();
    final alpha = pixels[index + 3].toDouble() / 255.0;
    if (alpha < 0.25) {
      continue;
    }

    final color = Color.fromARGB(
      (alpha * 255).round(),
      red.round(),
      green.round(),
      blue.round(),
    );
    final hsl = HSLColor.fromColor(color);
    final weight = (0.55 + hsl.saturation * 0.45) * alpha;
    redSum += red * weight;
    greenSum += green * weight;
    blueSum += blue * weight;
    sampleCount += weight;

    final emphasisScore = hsl.saturation * 1.6 + hsl.lightness;
    if (emphasisScore > highestScore) {
      highestScore = emphasisScore;
      brightest = color;
    }
  }

  if (sampleCount == 0) {
    return _fallbackPalette();
  }

  final averageColor = Color.fromARGB(
    255,
    (redSum / sampleCount).round(),
    (greenSum / sampleCount).round(),
    (blueSum / sampleCount).round(),
  );
  final primary = HSLColor.fromColor(averageColor)
      .withLightness(0.48)
      .withSaturation((HSLColor.fromColor(averageColor).saturation + 0.12).clamp(0.22, 0.82))
      .toColor();
  final accent = HSLColor.fromColor(brightest)
      .withLightness((HSLColor.fromColor(brightest).lightness + 0.08).clamp(0.42, 0.72))
      .withSaturation((HSLColor.fromColor(brightest).saturation + 0.1).clamp(0.28, 0.9))
      .toColor();
  final surface = HSLColor.fromColor(primary)
      .withLightness(0.16)
      .withSaturation((HSLColor.fromColor(primary).saturation * 0.52).clamp(0.12, 0.38))
      .toColor();

  return ClubThemePaletteResult(
    primaryColor: primary,
    accentColor: accent,
    surfaceColor: surface,
  );
}

ClubThemePaletteResult _fallbackPalette() {
  return const ClubThemePaletteResult(
    primaryColor: Color(0xFF2563EB),
    accentColor: Color(0xFF22C55E),
    surfaceColor: Color(0xFF0F172A),
  );
}
