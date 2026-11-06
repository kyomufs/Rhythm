import 'package:rhythm/core/domain/source.dart';
import 'package:rhythm/core/sources/source_provider.dart';
import 'package:rhythm/core/sources/tulsu/tulsu_provider.dart';

const manualSourceProvider = ManualSourceProvider();
const tulsuSourceProvider = TulsuSourceProvider();

/// Единственное место регистрации. Новый вуз/школа = новый файл провайдера
/// и строка здесь; экраны трогать не нужно.
final Map<String, SourceProvider> sourceProviders = {
  manualSourceProvider.id: manualSourceProvider,
  tulsuSourceProvider.id: tulsuSourceProvider,
};

/// Провайдеры, которые пользователь может выбрать при добавлении источника.
List<SourceProvider> get selectableProviders => sourceProviders.values
    .where((provider) => provider.id != manualSourceProvider.id)
    .toList();

SourceProvider providerFor(Source? source) {
  if (source == null) return manualSourceProvider;
  return sourceProviders[source.providerId] ?? manualSourceProvider;
}
