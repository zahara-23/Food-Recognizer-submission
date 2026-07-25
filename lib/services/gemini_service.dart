import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/nutrition_info.dart';

/// Wrapper untuk Generative AI dengan Gemini API, dipakai untuk
/// mengestimasi kandungan gizi makanan berdasarkan nama hasil inferensi
/// model ML (Kriteria 3 - Advanced).
///
/// API key TIDAK di-hardcode di kode maupun disematkan ke dalam
/// repository; diambil dari file `.env` (lihat `GEMINI_API_KEY`) yang
/// dimuat lewat package `flutter_dotenv`. Sesuai ketentuan kriteria,
/// "Tidak harus menyematkan API Key pada project", jadi reviewer bisa
/// memasukkan API key mereka sendiri sebelum menjalankan aplikasi.
class GeminiService {
  GeminiService._();

  static const String _systemInstruction =
      'Saya adalah suatu mesin yang mampu mengidentifikasi nutrisi atau '
      'kandungan gizi pada makanan layaknya uji laboratorium makanan. Hal '
      'yang bisa diidentifikasi adalah kalori, karbohidrat, lemak, serat, '
      'dan protein pada makanan. Satuan dari indikator tersebut berupa gram, '
      'kecuali kalori dalam kkal. Selalu balas HANYA dalam format JSON valid '
      'tanpa markdown code fence, dengan struktur persis: '
      '{"calories": number, "carbohydrate": number, "fat": number, '
      '"fiber": number, "protein": number}';

  static Future<NutritionInfo> getNutritionInfo(String foodName) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey.startsWith('PASTE_')) {
      throw Exception(
        'GEMINI_API_KEY belum diatur. Isi file .env dengan API key dari '
        'Google AI Studio terlebih dahulu.',
      );
    }

    final uri = Uri.parse(
      '${AppConstants.geminiBaseUrl}/${AppConstants.geminiModel}:generateContent?key=$apiKey',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': _systemInstruction},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'Nama makanannya adalah $foodName.'},
            ],
          },
        ],
        'generationConfig': {
          'response_mime_type': 'application/json',
          'temperature': 0.2,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API gagal (${response.statusCode}): ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini API tidak mengembalikan hasil.');
    }

    final parts = (candidates.first['content']?['parts'] as List<dynamic>?);
    final text = parts?.first['text'] as String?;
    if (text == null) {
      throw Exception('Format respons Gemini API tidak sesuai harapan.');
    }

    final cleanedText = text.replaceAll('```json', '').replaceAll('```', '').trim();
    final nutritionJson = jsonDecode(cleanedText) as Map<String, dynamic>;
    return NutritionInfo.fromJson(nutritionJson);
  }
}
