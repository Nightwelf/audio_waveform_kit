import 'package:voice_message/doc/example/domain/model/example_item.dart';
import 'package:voice_message/doc/example/domain/model/example_item_action/example_item_action.dart';

/// Репозиторий — единственный источник данных для BLoC.
///
/// Паттерн:
/// - `realtime` — broadcast-стрим доменных действий (не сырых RTU-событий)
/// - методы возвращают `AppResponse<T>`, не бросают исключения
/// - `dispose()` обязателен: закрывает стримы и отменяет подписки
abstract class ExampleItemsRepository {
  /// Realtime-поток: Created / Changed / Deleted / Reconnected / Disconnected.
  /// BLoC подписывается в конструкторе и отменяет в close().
  Stream<ExampleItemAction> get realtime;

  Future<AppResponse<List<ExampleItem>>> getItems({
    required String channelId,
    String? afterId,
    int count,
  });

  Future<AppResponse<ExampleItem>> getItem({
    required String channelId,
    required String itemId,
  });

  Future<void> dispose();
}
