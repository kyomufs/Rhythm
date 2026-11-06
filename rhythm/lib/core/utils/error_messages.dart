/// Centralized user-friendly error messages for network/API errors
class ErrorMessages {
  ErrorMessages._();

  /// Convert a raw exception to a user-friendly Russian message
  static String fromException(Object e) {
    final raw = e.toString().toLowerCase();

    // Network connectivity issues
    if (raw.contains('failed host lookup') ||
        raw.contains('name_not_resolved') ||
        raw.contains('socketexception')) {
      return 'Нет подключения к интернету';
    }
    if (raw.contains('connection refused') ||
        raw.contains('connection reset')) {
      return 'Сервер временно недоступен';
    }
    if (raw.contains('connection timed out') ||
        raw.contains('send timeout') ||
        raw.contains('receive timeout')) {
      return 'Превышено время ожидания';
    }
    if (raw.contains('connection closed') || raw.contains('unexpected eof')) {
      return 'Соединение разорвано';
    }
    if (raw.contains('certificate') || raw.contains('ssl')) {
      return 'Ошибка сертификата безопасности';
    }
    if (raw.contains('bad response') || raw.contains('status code 5')) {
      return 'Ошибка сервера ТулГУ';
    }
    if (raw.contains('bad request') || raw.contains('status code 4')) {
      return 'Неверный запрос';
    }

    // Default
    return 'Проверьте подключение к интернету';
  }
}
