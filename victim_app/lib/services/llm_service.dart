import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:victim_app/utils/constants.dart';
import '../models/chatbot_model.dart';

class LlmService {
  static final Dio dio = Dio();

  // Method to generate chat responses
  static Future<String> chatTextGenerationRepo(List<ChatMessageModel> previousMessages) async {
    try {
      // Prepare the request payload
      final response = await dio.post(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=${AppConstants.apiKey}",
        // https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${AppConstants.apiKey}
        data: {
          "contents": previousMessages.map((e) => e.toMap()).toList(),
          "generationConfig": {
            "temperature": 0.9,
            "topK": 1,
            "topP": 1,
            "maxOutputTokens": 2048,
            "stopSequences": []
          },
          "safetySettings": [
            {
              "category": "HARM_CATEGORY_HARASSMENT",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
              "category": "HARM_CATEGORY_HATE_SPEECH",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
              "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
              "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            }
          ]
        },
      );

      // Check for a successful response
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        return response.data['candidates'].first['content']['parts'].first['text'] ?? 'Sorry, I didn\'t understand that.';
      }

      // Log unexpected response status
      log('Unexpected response status: ${response.statusCode}');
      return 'There was an issue processing your request. Please try again.';
    } catch (e) {
      // Log any errors that occur during the request
      log('Error in chatTextGenerationRepo: ${e.toString()}');
      return 'An error occurred while trying to respond. Please try again later.';
    }
  }
}