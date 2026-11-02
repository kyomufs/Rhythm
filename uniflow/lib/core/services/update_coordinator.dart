import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uniflow/core/services/connectivity_service.dart';

/// Результат попытки обновления данных.
enum UpdateOutcome {
  /// Данные обновились — можно показывать уведомление.
  updated,

  /// API недоступен: ничего не произошло, экран не меняется.
  unavailable,

  /// API доступен, но запрос не удался — причина в [UpdateResult.message].
  failed,
}

class UpdateResult {
  const UpdateResult(this.outcome, [this.message]);

  final UpdateOutcome outcome;
  final String? message;

  /// Офлайн молчит: «если не доступно то ничего не происходит».
  static const unavailable = UpdateResult(UpdateOutcome.unavailable);

  bool get shouldNotify => outcome != UpdateOutcome.unavailable;
  bool get isSuccess => outcome == UpdateOutcome.updated;
}

final updateCoordinatorProvider = Provider<UpdateCoordinator>((ref) {
  return UpdateCoordinator(ref.watch(connectivityServiceProvider));
});

/// Единый путь обновления данных.
///
/// Порядок зафиксирован требованием: сначала проверка доступности API, и
/// только потом само обновление. Недоступный API означает «ничего не
/// происходит» — ни запроса, ни сообщения, ни изменения состояния.
class UpdateCoordinator {
  UpdateCoordinator(this._connectivity);

  final ConnectivityService _connectivity;

  /// Прогоняет [refresh] через проверку доступности.
  ///
  /// [refresh] вызывается только при живом API и обязан вернуть `updated` или
  /// `failed`.
  Future<UpdateResult> run(Future<UpdateResult> Function() refresh) async {
    // Пользователь нажал «обновить» — кэш вердикта (30 с) здесь врёт.
    _connectivity.invalidateCache();
    if (!await _connectivity.checkConnectivity()) {
      return UpdateResult.unavailable;
    }
    return refresh();
  }
}
