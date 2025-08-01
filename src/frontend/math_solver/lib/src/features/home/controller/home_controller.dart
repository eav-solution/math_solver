import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // MediaType
import 'package:mime/mime.dart';

import '../../../../config/app_config.dart'; // lookupMimeType

/*─────────────────────────────
 |  Model (image + markdown)   |
 ─────────────────────────────*/

@immutable
class SolveResult {
  final String markdown; // formatted response
  final File image; // local photo

  const SolveResult({required this.markdown, required this.image});
}

/*─────────────────────────────
 |  Provider                   |
 ─────────────────────────────*/

final homeControllerProvider =
    StateNotifierProvider<HomeController, AsyncValue<SolveResult?>>(
      (ref) => HomeController(),
    );

/*─────────────────────────────
 |  Controller                 |
 ─────────────────────────────*/

class HomeController extends StateNotifier<AsyncValue<SolveResult?>> {
  HomeController() : super(const AsyncData(null));

  // ⚠️ Change to your real backend IP if needed
  static final _endpoint = Uri.parse('${AppConfig.baseUrl}/solve');

  final _picker = ImagePicker();

  /*──── public API ────────────────────────────────────────────────────*/

  Future<void> takePhoto() =>
      _pickAndSolve(ImageSource.camera); // camera option

  Future<void> pickFromGallery() =>
      _pickAndSolve(ImageSource.gallery); // gallery option

  /*──── internal helpers ──────────────────────────────────────────────*/

  Future<void> _pickAndSolve(ImageSource src) async {
    try {
      final XFile? photo = await _picker.pickImage(source: src);
      if (photo == null) return; // user cancelled

      state = const AsyncLoading();

      // Build multipart/form-data
      final mimeType = lookupMimeType(photo.path) ?? 'image/jpeg';
      final mediaType = MediaType.parse(mimeType);

      final req = http.MultipartRequest('POST', _endpoint)
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            photo.path,
            contentType: mediaType,
          ),
        );

      final res = await http.Response.fromStream(await req.send());

      if (res.statusCode == 200) {
        state = AsyncData(
          SolveResult(
            markdown: _jsonToMarkdown(res.body),
            image: File(photo.path),
          ),
        );
      } else {
        state = AsyncError(
          'Server error (${res.statusCode})',
          StackTrace.current,
        );
      }
    } on SocketException {
      state = AsyncError(
        'Network error – check connection',
        StackTrace.current,
      );
    } catch (e, st) {
      state = AsyncError('Unexpected error: $e', st);
    }
  }

  /*──── JSON → Markdown ───────────────────────────────────────────────*/
  String _jsonToMarkdown(String body) {
    try {
      final decoded = jsonDecode(body);
      final map = decoded['response'] as Map<String, dynamic>;

      final b = StringBuffer();
      map.forEach((k, v) {
        b.writeln('### ${_cap(k)}');

        // Keep line breaks: 2 spaces + \n  → <br> in Markdown
        final text = v
            .toString()
            .split('\n')
            .map((line) => '${line.trim()}  ')
            .join('\n');

        b.writeln(text);
        b.writeln();
      });
      return b.toString();
    } catch (_) {
      return '### Response\n$body';
    }
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
