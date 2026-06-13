// lib/services/whatsapp_service.dart
import 'package:dio/dio.dart';

class WhatsAppService {
  final Dio _dio = Dio();
  String baseUrl;

  WhatsAppService({this.baseUrl = 'http://localhost:3000'});

  Future<bool> sendMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/send-message',
        data: {'phone': phoneNumber, 'message': message},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.statusCode == 200;
    } on DioException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, bool>> sendBatch({
    required List<Map<String, String>> payloads,
  }) async {
    final results = <String, bool>{};
    for (final p in payloads) {
      final phone = p['phone'] ?? '';
      final msg = p['message'] ?? '';
      if (phone.isEmpty) continue;
      final success = await sendMessage(phoneNumber: phone, message: msg);
      results[phone] = success;
    }
    return results;
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/health',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
