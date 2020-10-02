import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;

const GcpEuAuthUrl = 'https://auth.europe-west1.gcp.commercetools.com';
const GcpEuApiUrl = 'https://api.europe-west1.gcp.commercetools.com';
const GcpEuMlApiUrl = 'https://ml-eu.europe-west1.gcp.commercetools.com';

class Api {
  final String clientId;
  final String clientSecret;
  final String authUrl;
  final String apiUrl;
  final String mlApiUrl;
  String _accessToken;
  DateTime _accessTokenExpiryTime;

  Api(
      {this.clientId,
      this.clientSecret,
      this.authUrl,
      this.apiUrl,
      this.mlApiUrl});

  Future<http.Response> get(String project, String path,
      {Map<String, dynamic> queryParameters,
      Map<String, String> headers}) async {
    await _refreshAccessToken();
    final uri = _buildUri(project, path, queryParameters);
    headers = _buildHeaders(headers);
    return http.get(uri, headers: headers);
  }

  Future<http.Response> postMl(String project, String path, dynamic body,
      {Map<String, dynamic> queryParameters,
      Map<String, String> headers}) async {
    await _refreshAccessToken();
    final uri = _buildUri(project, path, queryParameters);
    headers = _buildHeaders(headers);
    return http.post(uri, headers: headers, body: body);
  }

  Uri _buildUri(
      String project, String path, Map<String, dynamic> queryParameters) {
    return Uri.parse('$mlApiUrl/$project$path')
        .replace(queryParameters: queryParameters ?? {});
  }

  Map<String, String> _buildHeaders(Map<String, String> headers) {
    return {
      ...?headers,
      HttpHeaders.authorizationHeader: 'Bearer $_accessToken',
    };
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
    final uri =
        Uri.parse('$authUrl/oauth/token').replace(queryParameters: params);
    final token = base64Encode(utf8.encode('$clientId:$clientSecret'));
    final headers = {HttpHeaders.authorizationHeader: 'Basic $token'};
    return http.post(uri, headers: headers);
  }
}

class ApiException implements Exception {
  final String cause;

  ApiException(this.cause);
}
