import 'dart:convert';
import 'package:http/http.dart' as http;

class KakaoApiService {
  final String apiKey;

  KakaoApiService({required this.apiKey});

  Future<Map<String, dynamic>> searchAddress(String query) async {
    // Use the exact same URL pattern as your working cURL command
    final baseUrl = 'https://dapi.kakao.com/v2/local/search/address.json';

    // Create URI with query parameters
    final uri = Uri.parse(baseUrl).replace(queryParameters: {'query': query});

    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'KakaoAK $apiKey'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get address data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during API call: $e');
      rethrow;
    }
  }
}
