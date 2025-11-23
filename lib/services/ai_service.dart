import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'logger_service.dart';

class AIService {
  final _logger = LoggerService();

  Future<String?> chat(String message) async {
    try {
      _logger.info('AI 请求: $message');
      
      final response = await http.post(
        Uri.parse(AppConstants.aiApiUrl),
        headers: {
          'Authorization': 'Bearer ${AppConstants.aiApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': AppConstants.aiModel,
          'messages': [
            {'role': 'user', 'content': message}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        _logger.info('AI 响应成功');
        return content;
      } else {
        _logger.error('AI 请求失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.error('AI 请求异常: $e');
      return null;
    }
  }
}
