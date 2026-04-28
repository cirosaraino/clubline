import 'dart:typed_data';

const Set<String> kAllowedClubLogoMimeTypes = {
  'image/png',
  'image/jpeg',
  'image/jpg',
  'image/webp',
  'image/gif',
  'image/svg+xml',
};
const int kMaxClubLogoBytes = 5 * 1024 * 1024;

class PickedClubLogo {
  const PickedClubLogo({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.dataUrl,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final String dataUrl;

  bool get isSvg {
    final normalizedMimeType = mimeType.trim().toLowerCase();
    final normalizedFileName = fileName.trim().toLowerCase();
    if (normalizedMimeType.contains('svg') ||
        normalizedFileName.endsWith('.svg')) {
      return true;
    }

    if (bytes.isEmpty) {
      return false;
    }

    final headerLength = bytes.length < 120 ? bytes.length : 120;
    final header = String.fromCharCodes(
      bytes.take(headerLength),
    ).trimLeft().toLowerCase();
    return header.startsWith('<?xml') || header.startsWith('<svg');
  }
}

String? validatePickedClubLogo(PickedClubLogo logo) {
  final normalizedMimeType = logo.mimeType.trim().toLowerCase();
  if (!kAllowedClubLogoMimeTypes.contains(normalizedMimeType) && !logo.isSvg) {
    return 'Formato logo non supportato. Usa PNG, JPG, WEBP, GIF o SVG.';
  }

  if (logo.bytes.isEmpty) {
    return 'Il file selezionato e vuoto.';
  }

  if (logo.bytes.length > kMaxClubLogoBytes) {
    return 'Il logo deve essere inferiore a 5 MB.';
  }

  return null;
}
