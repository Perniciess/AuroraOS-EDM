import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status, this.requestId, this.network = false});

  final String message;
  final int? status;
  final String? requestId;
  final bool network;
}

/// Never logs credentials or follows authenticated redirects.
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
      throw const ApiFailure('Сервер не отвечает. Проверьте связь и повторите.', network: true);
    } on TlsException {
      throw const ApiFailure('Не удалось проверить защищённое соединение с сервером.');
    } on IOException {
      throw const ApiFailure('Нет соединения с сервером. Проверьте сеть.', network: true);
    } on FormatException {
      throw const ApiFailure('Сервер вернул некорректный ответ.');
    } on TypeError {
      throw const ApiFailure('Ответ сервера не соответствует контракту.');
    }
  }

  /// Full restart on retry: partial files are never treated as cached content.
  Future<void> download(String path, String token, File destination,
      int expectedSize, void Function(int) onProgress) async {
    final base = _base;
    if (base == null) throw const ApiFailure('Укажите HTTPS-адрес сервера в EDM_API_URL.');
    if (expectedSize <= 0 || expectedSize > 100 * 1024 * 1024) {
      throw const ApiFailure('Недопустимый размер PDF (максимум 100 МиБ).');
    }
    HttpClientRequest? active;
    var expired = false;
    final timer = Timer(const Duration(minutes: 5), () {
      expired = true;
      active?.abort();
    });
    IOSink? sink;
    try {
      final request = await _http.getUrl(base.replace(path: path)).then((request) {
        if (expired) request.abort();
        return request;
      }).timeout(const Duration(seconds: 15), onTimeout: () {
        expired = true;
        throw TimeoutException('Connection deadline');
      });
      active = request;
      if (expired) throw TimeoutException('Download deadline');
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/pdf');
      final response = await request.close().timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw ApiFailure(
          response.statusCode == 404 ? 'Документ больше недоступен.' :
          response.statusCode == 401 ? 'Сессия истекла. Войдите заново.' :
          'Не удалось скачать PDF. Повторите попытку.',
          status: response.statusCode,
          requestId: response.headers.value('x-request-id'),
        );
      }
      if (response.contentLength != -1 && response.contentLength != expectedSize) {
        throw const ApiFailure('Размер PDF не соответствует назначенной версии.');
      }
      sink = destination.openWrite();
      // Observe disk errors immediately, including before flush/close.
      final output = sink;
      Object? writeError;
      unawaited(output.done.catchError((Object error) { writeError = error; }));
      var received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 25))) {
        if (expired) throw TimeoutException('Download deadline');
        if (writeError != null) throw const ApiFailure('Не удалось сохранить PDF. Проверьте свободное место.');
        received += chunk.length;
        if (received > expectedSize) throw const ApiFailure('PDF превышает ожидаемый размер.');
        output.add(chunk);
        await output.flush();
        onProgress(received);
      }
      await output.close();
      sink = null;
      if (received != expectedSize) throw const ApiFailure('PDF загружен не полностью. Повторите скачивание.');
    } on TimeoutException {
      throw const ApiFailure('Скачивание прервано по таймауту. Повторите попытку.', network: true);
    } on TlsException {
      throw const ApiFailure('Не удалось проверить защищённое соединение с сервером.');
    } on SocketException {
      throw const ApiFailure('Соединение прервано. Повторите скачивание.', network: true);
    } on HttpException {
      throw const ApiFailure('Соединение прервано. Повторите скачивание.', network: true);
    } on FileSystemException {
      throw const ApiFailure('Не удалось сохранить PDF. Проверьте свободное место.');
    } finally {
      timer.cancel();
      active?.abort();
      if (sink != null) {
        try { await sink.close(); } catch (_) { /* Preserve original failure. */ }
      }
    }
  }

  void close() => _http.close(force: true);
}
