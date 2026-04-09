import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import '../config/api.dart';
import '../utils/storage.dart';

/// 全局导航 Key — 用于在非 Widget 上下文中跳转（如 Token 过期）
/// 需要在 MaterialApp 中设置: navigatorKey: HttpClient.navigatorKey
import 'package:flutter/material.dart';

class HttpClient {
  static final HttpClient _instance = HttpClient._internal();
  factory HttpClient() => _instance;

  /// 全局导航 Key（在 main.dart 中绑定到 MaterialApp）
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  late Dio _dio;

  HttpClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 🔧 配置代理（仅原生平台开发环境）
    // 需要抓包时取消下方注释，并添加 import 'dart:io' as io; 和 import 'package:dio/io.dart';
    // if (kDebugMode && !kIsWeb) {
    //   (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    //     final client = io.HttpClient();
    //     client.findProxy = (uri) => 'PROXY 127.0.0.1:8888';
    //     client.badCertificateCallback = (cert, host, port) => true;
    //     return client;
    //   };
    // }

    // 请求拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 注入 Token
        final token = await StorageUtil.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // 注入语言参数（放到请求头）
        final lang = await StorageUtil.getLanguage();
        options.headers['X-Lang'] = lang;

        handler.next(options);
      },
      onResponse: (response, handler) {
        // ⚠️ 修复：在响应层统一检测业务错误码
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final code = data['code'];
          if (code == 1001 || code == 1002 || code == 1003) {
            // Token 相关错误 — 清理并跳转登录
            _handleTokenExpired();
          }
        }
        handler.next(response);
      },
      onError: (error, handler) {
        // ⚠️ 修复：完善网络错误处理
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout) {
          error = error.copyWith(
            error: '网络连接超时，请检查网络后重试',
          );
        } else if (error.type == DioExceptionType.connectionError) {
          error = error.copyWith(
            error: '无法连接服务器，请检查网络',
          );
        }

        // HTTP 401
        if (error.response?.statusCode == 401) {
          _handleTokenExpired();
        }

        // 尝试从响应体获取业务错误码
        final responseData = error.response?.data;
        if (responseData is Map<String, dynamic>) {
          final code = responseData['code'];
          if (code == 1001 || code == 1002 || code == 1003) {
            _handleTokenExpired();
          }
        }

        handler.next(error);
      },
    ));

    // 日志拦截器（仅 debug 模式）
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  /// Token 过期统一处理
  void _handleTokenExpired() async {
    // 游客本来就没有 Token，不需要跳转登录页
    final token = await StorageUtil.getToken();
    if (token == null || token.isEmpty) return;

    StorageUtil.clearToken();
    StorageUtil.clearUserInfo();

    // 使用全局导航 Key 跳转登录页
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Dio get dio => _dio;

  /// GET 请求
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: params);
      return _parseResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// POST 请求
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
  }) async {
    try {
      final response = await _dio.post(path, data: data);
      return _parseResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// 上传文件
  Future<Map<String, dynamic>> upload(
    String path, {
    required String filePath,
    String fieldName = 'file',
    String? fileName,
    MediaType? contentType,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: contentType,
        ),
        ...?extra,
      });

      final response = await _dio.post(path, data: formData);
      return _parseResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// 上传文件（从字节，兼容 Web）
  Future<Map<String, dynamic>> uploadBytes(
    String path, {
    required List<int> bytes,
    required String fileName,
    String fieldName = 'file',
    MediaType? contentType,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: contentType,
        ),
      });

      final response = await _dio.post(path, data: formData);
      return _parseResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// 批量上传
  Future<Map<String, dynamic>> uploadMultiple(
    String path, {
    required List<String> filePaths,
    String fieldName = 'files',
  }) async {
    try {
      final files = await Future.wait(
        filePaths.map((p) => MultipartFile.fromFile(p)),
      );

      final formData = FormData.fromMap({
        fieldName: files,
      });

      final response = await _dio.post(path, data: formData);
      return _parseResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// ⚠️ 新增：统一解析响应
  Map<String, dynamic> _parseResponse(Response response) {
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    // 意外响应格式
    return {
      'code': -1,
      'msg': '服务器响应格式异常',
      'data': null,
    };
  }

  /// ⚠️ 新增：统一处理 Dio 异常，返回标准格式而非抛异常
  Map<String, dynamic> _handleDioError(DioException e) {
    // 尝试返回服务端错误信息
    if (e.response?.data is Map<String, dynamic>) {
      return e.response!.data as Map<String, dynamic>;
    }

    String msg;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        msg = '网络连接超时，请重试';
        break;
      case DioExceptionType.connectionError:
        msg = '无法连接服务器';
        break;
      default:
        msg = '网络异常，请稍后再试';
    }

    return {
      'code': -1,
      'msg': msg,
      'data': null,
    };
  }
}
