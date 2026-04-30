// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../screens/offline_diagnosis_engine.dart';


class ApiService {
  static const String _base =
      'https://financial-discover-winter.ngrok-free.dev';

  // ─── Maternal ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> diagnoseMaternel(
      Map<String, dynamic> body) async {
    return _post('/diagnosis/maternal', body);
  }

  // ─── TB ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> diagnoseTb(
      Map<String, dynamic> body) async {
    return _post('/diagnosis/tb', body);
  }

  // ─── Pesticide ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> diagnosePesticide(
      Map<String, dynamic> body) async {
    return _post('/diagnosis/pesticide', body);
  }

  // ─── DFU (multipart with image) ───────────────────────────────────────────
  static Future<Map<String, dynamic>> diagnoseDfu({
    required File image,
    required String pain,
    required String swelling,
    required String duration,
    required String language,
  }) async {
    final uri = Uri.parse('$_base/diagnosis/dfu');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('image', image.path));
    request.fields['pain']     = pain;
    request.fields['swelling'] = swelling;
    request.fields['duration'] = duration;
    request.fields['language'] = language;

    final streamed =
    await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(
        'DFU API error ${response.statusCode}: ${response.body}');
  }

  // ─── Generic POST ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_base$path');
    final response = await http
        .post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(
        'API error ${response.statusCode}: ${response.body}');
  }

  // ─── Offline Fallbacks ────────────────────────────────────────────────────
  // Called by the screen when ConnectivityService reports offline.
  // These mirror the exact same scoring rules as the Python backend.

  static Map<String, dynamic> offlineMaternel(
      Map<String, dynamic> body) =>
      OfflineDiagnosisEngine.diagnoseMaternel(body,
          language: body['language']?.toString() ?? 'english');

  static Map<String, dynamic> offlineTb(Map<String, dynamic> body) =>
      OfflineDiagnosisEngine.diagnoseTb(body,
          language: body['language']?.toString() ?? 'english');

  static Map<String, dynamic> offlinePesticide(
      Map<String, dynamic> body) =>
      OfflineDiagnosisEngine.diagnosePesticide(body,
          language: body['language']?.toString() ?? 'english');

  static Map<String, dynamic> offlineDfu(Map<String, dynamic> body) =>
      OfflineDiagnosisEngine.diagnoseDfu(body,
          language: body['language']?.toString() ?? 'english');
}