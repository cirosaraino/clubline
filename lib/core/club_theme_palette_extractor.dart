import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'club_logo_resolver.dart';

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
  if (_looksLikeSvg(bytes)) {
    return _extractSvgPalette(bytes);
  }

  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: 48,
    targetHeight: 48,
  );
  final frame = await codec.getNextFrame();
  final byteData = await frame.image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  if (byteData == null) {
    return fallbackClubThemePalette();
  }

  final pixels = byteData.buffer.asUint8List();
  if (pixels.isEmpty) {
    return fallbackClubThemePalette();
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
    return fallbackClubThemePalette();
  }

  final averageColor = Color.fromARGB(
    255,
    (redSum / sampleCount).round(),
    (greenSum / sampleCount).round(),
    (blueSum / sampleCount).round(),
  );
  final primary = HSLColor.fromColor(averageColor)
      .withLightness(0.48)
      .withSaturation(
        (HSLColor.fromColor(averageColor).saturation + 0.12).clamp(0.22, 0.82),
      )
      .toColor();
  final accent = HSLColor.fromColor(brightest)
      .withLightness(
        (HSLColor.fromColor(brightest).lightness + 0.08).clamp(0.42, 0.72),
      )
      .withSaturation(
        (HSLColor.fromColor(brightest).saturation + 0.1).clamp(0.28, 0.9),
      )
      .toColor();
  final surface = HSLColor.fromColor(primary)
      .withLightness(0.16)
      .withSaturation(
        (HSLColor.fromColor(primary).saturation * 0.52).clamp(0.12, 0.38),
      )
      .toColor();

  return ClubThemePaletteResult(
    primaryColor: primary,
    accentColor: accent,
    surfaceColor: surface,
  );
}

Future<ClubThemePaletteResult> extractClubThemePaletteFromUrl(
  String logoUrl,
) async {
  final response = await http
      .get(Uri.parse(logoUrl))
      .timeout(const Duration(seconds: 4));
  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      response.bodyBytes.isEmpty) {
    return fallbackClubThemePalette();
  }

  return extractClubThemePalette(response.bodyBytes);
}

Future<ClubThemePaletteResult> extractClubThemePaletteFromLogoReference({
  String? logoStoragePath,
  String? logoUrl,
  ClubLogoResolver? resolver,
}) async {
  final resolvedUrl = await (resolver ?? ClubLogoResolver.instance).resolveUrl(
    storagePath: logoStoragePath,
    fallbackUrl: logoUrl,
  );
  if (resolvedUrl == null) {
    return fallbackClubThemePalette();
  }

  return extractClubThemePaletteFromUrl(resolvedUrl);
}

bool _looksLikeSvg(Uint8List bytes) {
  if (bytes.isEmpty) {
    return false;
  }

  final headerLength = bytes.length < 180 ? bytes.length : 180;
  final header = utf8
      .decode(bytes.sublist(0, headerLength), allowMalformed: true)
      .trimLeft()
      .toLowerCase();
  return header.startsWith('<?xml') || header.startsWith('<svg');
}

ClubThemePaletteResult _extractSvgPalette(Uint8List bytes) {
  final source = utf8.decode(bytes, allowMalformed: true);
  final matches = RegExp(
    r'#[0-9a-fA-F]{3,8}\b|rgb\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)',
  ).allMatches(source);

  final weightedColors = <Color, double>{};
  for (final match in matches) {
    final rawValue = match.group(0);
    final color = rawValue == null ? null : _parseSvgColor(rawValue);
    if (color == null) {
      continue;
    }

    final hsl = HSLColor.fromColor(color);
    if (hsl.saturation < 0.05 &&
        (hsl.lightness < 0.16 || hsl.lightness > 0.9)) {
      continue;
    }

    final weight = 0.6 + hsl.saturation + (1 - (hsl.lightness - 0.52).abs());
    weightedColors.update(
      color,
      (current) => current + weight,
      ifAbsent: () => weight,
    );
  }

  if (weightedColors.isEmpty) {
    return fallbackClubThemePalette();
  }

  final ranked = weightedColors.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));

  final primarySeed = ranked.first.key;
  final accentSeed = ranked.map((entry) => entry.key).toList().fold<Color>(
    primarySeed,
    (best, candidate) {
      final bestHsl = HSLColor.fromColor(best);
      final candidateHsl = HSLColor.fromColor(candidate);
      final bestScore = bestHsl.saturation * 1.5 + bestHsl.lightness;
      final candidateScore =
          candidateHsl.saturation * 1.5 + candidateHsl.lightness;
      return candidateScore > bestScore ? candidate : best;
    },
  );

  final primaryHsl = HSLColor.fromColor(primarySeed);
  final accentHsl = HSLColor.fromColor(accentSeed);
  final primary = primaryHsl
      .withLightness(primaryHsl.lightness.clamp(0.34, 0.56))
      .withSaturation((primaryHsl.saturation + 0.1).clamp(0.22, 0.88))
      .toColor();
  final accent = accentHsl
      .withLightness((accentHsl.lightness + 0.08).clamp(0.44, 0.74))
      .withSaturation((accentHsl.saturation + 0.08).clamp(0.28, 0.92))
      .toColor();
  final surface = HSLColor.fromColor(primary)
      .withLightness(0.16)
      .withSaturation(
        (HSLColor.fromColor(primary).saturation * 0.5).clamp(0.12, 0.36),
      )
      .toColor();

  return ClubThemePaletteResult(
    primaryColor: primary,
    accentColor: accent,
    surfaceColor: surface,
  );
}

Color? _parseSvgColor(String rawValue) {
  final normalized = rawValue.trim().toLowerCase();

  if (normalized.startsWith('#')) {
    final hex = normalized.substring(1);
    if (hex.length == 3) {
      final expanded = hex.split('').map((char) => '$char$char').join();
      final parsed = int.tryParse(expanded, radix: 16);
      return parsed == null ? null : Color(0xFF000000 | parsed);
    }

    if (hex.length == 6) {
      final parsed = int.tryParse(hex, radix: 16);
      return parsed == null ? null : Color(0xFF000000 | parsed);
    }

    if (hex.length == 8) {
      final rgb = hex.substring(0, 6);
      final parsed = int.tryParse(rgb, radix: 16);
      return parsed == null ? null : Color(0xFF000000 | parsed);
    }
  }

  final rgbMatch = RegExp(
    r'rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)',
  ).firstMatch(normalized);
  if (rgbMatch != null) {
    return Color.fromARGB(
      255,
      int.parse(rgbMatch.group(1)!),
      int.parse(rgbMatch.group(2)!),
      int.parse(rgbMatch.group(3)!),
    );
  }

  return null;
}

ClubThemePaletteResult fallbackClubThemePalette() {
  return const ClubThemePaletteResult(
    primaryColor: Color(0xFF2563EB),
    accentColor: Color(0xFF22C55E),
    surfaceColor: Color(0xFF0F172A),
  );
}

bool isFallbackClubThemePalette(ClubThemePaletteResult result) {
  final fallback = fallbackClubThemePalette();
  return result.primaryColor.toARGB32() == fallback.primaryColor.toARGB32() &&
      result.accentColor.toARGB32() == fallback.accentColor.toARGB32() &&
      result.surfaceColor.toARGB32() == fallback.surfaceColor.toARGB32();
}
