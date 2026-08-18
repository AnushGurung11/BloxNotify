import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/fruit.dart';
import '../models/prediction.dart';

/// Thrown when the backend cannot be reached or answers unexpectedly.
class StockApiException implements Exception {
  StockApiException(this.message);

  final String message;

  @override
  String toString() => 'StockApiException: $message';
}

/// Client for the Blox Notify backend's GET /stock endpoint.
class StockApi {
  StockApi({http.Client? client, String baseUrl = AppConfig.apiBaseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl; // ignore: prefer_initializing_formals

  final http.Client _client;
  final String _baseUrl;

  Future<StockSnapshot> fetchCurrentStock() async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$_baseUrl/stock'))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw StockApiException('Could not reach the server ($e)');
    }

    if (response.statusCode != 200) {
      throw StockApiException('Server responded with ${response.statusCode}');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw StockApiException('Unexpected server response ($e)');
    }

    return StockSnapshot.fromJson(body);
  }

  /// Fetches the predicted fruits for the next rotation. Returns null when
  /// the backend has no model yet (history not loaded).
  Future<PredictionResult?> fetchPredictions() async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$_baseUrl/stock/predictions'))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw StockApiException('Could not reach the server ($e)');
    }

    if (response.statusCode != 200) {
      throw StockApiException('Server responded with ${response.statusCode}');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw StockApiException('Unexpected server response ($e)');
    }

    if (body['ready'] != true) return null;
    return PredictionResult.fromJson(body);
  }
}