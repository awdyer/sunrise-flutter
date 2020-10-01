import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

const GcpEuApiUrl = 'https://api.europe-west1.gcp.commercetools.com';
const GcpEuAuthUrl = 'https://auth.europe-west1.gcp.commercetools.com';

class Api {
  final String clientId;
  final String clientSecret;
  final String apiUrl;
  final String authUrl;
  String _accessToken;
  DateTime _accessTokenExpiryTime;

  Api({this.clientId, this.clientSecret, this.apiUrl, this.authUrl});

  Future<http.Response> get(project, path, {queryParameters}) async {
    await _refreshAccessToken();
    final uri = Uri.parse('$apiUrl/$project$path')
        .replace(queryParameters: queryParameters ?? {});
    final headers = {
      HttpHeaders.authorizationHeader: 'Bearer $_accessToken',
    };
    return http.get(uri, headers: headers);
  }

  Future _refreshAccessToken() async {
    final now = DateTime.now();

    if (_accessTokenExpiryTime != null &&
        now.isBefore(_accessTokenExpiryTime)) {
      return;
    }

    final response = await _fetchAccessToken();
    if (response.statusCode != 200) {
      log(response.body);
      throw ApiException('Failed to get token.');
    }

    final Map<String, dynamic> body = json.decode(response.body);
    final accessToken = body['access_token'];
    final expiresIn = body['expires_in'];

    _accessToken = accessToken;
    _accessTokenExpiryTime = now.add(Duration(seconds: expiresIn));
  }

  Future<http.Response> _fetchAccessToken() {
    final params = {'grant_type': 'client_credentials'};
    final uri = Uri.parse('$authUrl/oauth/token')
        .replace(queryParameters: params);
    final token =
        base64Encode(utf8.encode('$clientId:$clientSecret'));
    final headers = {HttpHeaders.authorizationHeader: 'Basic $token'};
    return http.post(uri, headers: headers);
  }
}

class ApiException implements Exception {
  final String cause;

  ApiException(this.cause);
}
