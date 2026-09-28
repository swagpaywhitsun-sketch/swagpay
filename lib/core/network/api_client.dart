import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException({required this.message, this.statusCode, this.details});

  @override
  String toString() => 'ApiException: $message (code: $statusCode)';
}

class ApiClient {
  late final Dio _dio;
  String? _authToken;

  ApiClient({String? initialToken}) {
    _authToken = initialToken;
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: ApiConfig.connectTimeoutSeconds),
        receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeoutSeconds),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-App': 'SwagPay-Flutter',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          // Inject idempotency key for mutations if not present
          if (options.method != 'GET' && !options.headers.containsKey('X-Idempotency-Key')) {
            options.headers['X-Idempotency-Key'] = const Uuid().v4();
          }
          dev.log('--> ${options.method} ${options.uri}', name: 'API');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          dev.log('<-- ${response.statusCode} ${response.requestOptions.uri}', name: 'API');
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          dev.log('API Error: ${error.message} [${error.response?.statusCode}]', name: 'API');
          return handler.next(error);
        },
      ),
    );
  }

  void updateToken(String? token) {
    _authToken = token;
  }

  void updateBaseUrl(String newUrl) {
    ApiConfig.baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(path, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    String? idempotencyKey,
  }) async {
    try {
      final opts = Options();
      if (idempotencyKey != null) {
        opts.headers = {'X-Idempotency-Key': idempotencyKey};
      }
      return await _dio.post<T>(path, data: data, queryParameters: queryParameters, options: opts);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.put<T>(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.delete<T>(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiException _handleDioError(DioException e) {
    String msg = 'An unexpected error occurred. Please try again.';
    if (e.response != null && e.response?.data is Map) {
      final map = e.response!.data as Map;
      msg = map['message']?.toString() ?? map['error']?.toString() ?? msg;
    } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      msg = 'Connection timeout. Check your network.';
    } else if (e.type == DioExceptionType.connectionError) {
      msg = 'Cannot connect to server. Please check internet connection.';
    }
    return ApiException(message: msg, statusCode: e.response?.statusCode, details: e.response?.data);
  }
}
