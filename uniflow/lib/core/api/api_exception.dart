/// Ошибка API источника: провайдер приводит к ней сетевые сбои,
/// чтобы экраны показывали один и тот же текст.
class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}
