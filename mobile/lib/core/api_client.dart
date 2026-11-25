import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status, this.requestId});

  final String message;
  final int? status;
  final String? requestId;
}

/// JSON-only transport. Never logs credentials or follows authenticated redirects.
class ApiClient {
  ApiClient(String endpoint) : _base = _parseEndpoint(endpoint);

  final Uri? _base;
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  static Uri? _parseEndpoint(String endpoint) {
    final uri = Uri.tryParse(endpoint);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return null;
    }
    return uri;
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    String? token,
    Map<String, String>? body,
    Map<String, String>? query,
  }) async {
    final base = _base;
    if (base == null) {
      throw const ApiFailure('Укажите HTTPS-адрес сервера в EDM_API_URL.');
    }
    HttpClientRequest? active;
    var timedOut = false;
    try {
      return await (() async {
        final request = await _http.openUrl(
          method, base.replace(path: path, queryParameters: query),
        );
        active = request;
        if (timedOut) {
          request.abort();
          throw const ApiFailure('Время ожидания запроса истекло.');
        }
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        if (token != null) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        }
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(body));
        }
        final response = await request.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          if (bytes.length + chunk.length > 1024 * 1024) {
            throw const ApiFailure('Ответ сервера слишком большой.');
          }
          bytes.addAll(chunk);
        }
        final status = response.statusCode;
        if (status < 200 || status >= 300) {
          throw ApiFailure(
            switch (status) {
              401 => 'Проверьте логин и пароль или войдите заново.',
              404 => 'Документ недоступен. Обновите список заданий.',
              429 => 'Слишком много попыток. Повторите вход через 15 минут.',
              _ => 'Сервер не выполнил запрос. Попробуйте позже.',
            },
            status: status,
            requestId: response.headers.value('x-request-id'),
          );
        }
        if (status == 204) return <String, dynamic>{};
        return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      })().timeout(const Duration(seconds: 25), onTimeout: () {
        timedOut = true;
        active?.abort();
        throw TimeoutException('Request deadline exceeded');
      });
    } on TimeoutException {
      active?.abort();
      throw const ApiFailure('Сервер не отвечает. Проверьте связь и повторите.');
    } on IOException {
      throw const ApiFailure('Нет соединения с сервером. Проверьте сеть.');
    } on FormatException {
      throw const ApiFailure('Сервер вернул некорректный ответ.');
    } on TypeError {
      throw const ApiFailure('Ответ сервера не соответствует контракту.');
    }
  }

  void close() => _http.close(force: true);
}
