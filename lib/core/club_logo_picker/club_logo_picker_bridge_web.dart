// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'club_logo_picker_types.dart';

Future<PickedClubLogo?> pickClubLogo() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  final completer = Completer<PickedClubLogo?>();
  input.onChange.listen((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return;
    }

    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is! String || result.trim().isEmpty) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        return;
      }

      final base64Payload = result.split(',').length > 1 ? result.split(',').last : '';
      final bytes = Uint8List.fromList(base64Decode(base64Payload));
      if (!completer.isCompleted) {
        completer.complete(
          PickedClubLogo(
            fileName: file.name,
            mimeType: file.type.isEmpty ? 'image/png' : file.type,
            bytes: bytes,
            dataUrl: result,
          ),
        );
      }
    });
    reader.readAsDataUrl(file);
  });

  input.click();
  return completer.future;
}
