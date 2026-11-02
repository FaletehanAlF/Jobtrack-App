// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import '../models/cv_file.dart';

Future<PickedCvFile?> pickCvFile() {
  final input = html.FileUploadInputElement()
    ..accept = 'application/pdf,.pdf'
    ..style.display = 'none';

  html.document.body?.append(input);

  final completer = Completer<PickedCvFile?>();
  StreamSubscription<html.Event>? changeSub;
  StreamSubscription<html.Event>? focusSub;

  void finish(PickedCvFile? file) {
    if (completer.isCompleted) return;

    changeSub?.cancel();
    focusSub?.cancel();
    input.remove();
    completer.complete(file);
  }

  changeSub = input.onChange.listen((_) async {
    final files = input.files;

    if (files == null || files.isEmpty) {
      finish(null);
      return;
    }

    final file = files.first;
    final reader = html.FileReader();

    try {
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first.timeout(const Duration(seconds: 30));
    } catch (_) {
      finish(null);
      return;
    }

    final result = reader.result;

    if (result is ByteBuffer) {
      finish(
        PickedCvFile(
          name: file.name,
          bytes: Uint8List.view(result),
        ),
      );
      return;
    }

    finish(null);
  });

  // Dialog file yang dibatalkan tidak memicu onChange. Saat jendela kembali
  // fokus dan tidak ada file, selesaikan dengan null agar tombol tidak macet.
  focusSub = html.window.onFocus.listen((_) {
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted && (input.files?.isEmpty ?? true)) {
        finish(null);
      }
    });
  });

  input.click();

  return completer.future;
}
