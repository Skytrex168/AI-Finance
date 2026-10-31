import 'package:dio/dio.dart';
import '../storage/token_storage.dart';

const String kBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');

/// Dio client: attaches the JWT, and on 401 silently refreshes once then retries.
class ApiClient {
  final TokenStorage storage;
  final void Function() onSessionExpired;
  late final Dio dio;
  final Dio _plain = Dio(BaseOptions(baseUrl: kBaseUrl, connectTimeout: const Duration(seconds: 10)));

  ApiClient(this.storage, this.onSessionExpired) {
    dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (!options.path.startsWith('/api/auth/')) {
          final t = await storage.access;
          if (t != null) options.headers['Authorization'] = 'Bearer $t';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final isAuthCall = e.requestOptions.path.startsWith('/api/auth/');
        if (e.response?.statusCode == 401 && !isAuthCall && e.requestOptions.extra['retried'] != true) {
          final ok = await _refresh();
          if (ok) {
            final opts = e.requestOptions..extra['retried'] = true;
            opts.headers['Authorization'] = 'Bearer ${await storage.access}';
            try {
              return handler.resolve(await dio.fetch(opts));
            } on DioException catch (e2) {
              return handler.next(e2);
            }
          }
          await storage.clear();
          onSessionExpired();
        }
        handler.next(e);
      },
    ));
  }

  Future<bool> _refresh() async {
    final rt = await storage.refresh;
    if (rt == null) return false;
    try {
      final r = await _plain.post('/api/auth/refresh', data: {'refreshToken': rt});
      await storage.save(r.data['accessToken'], r.data['refreshToken']);
      return true;
    } catch (_) {
      return false;
    }
  }
}

String errorMessage(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['error'] != null) return d['error'].toString();
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the server. Check your connection.';
    }
    return 'Request failed (${e.response?.statusCode ?? 'no response'})';
  }
  return 'Something went wrong';
}
