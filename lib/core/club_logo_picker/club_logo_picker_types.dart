import 'dart:typed_data';

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
}
