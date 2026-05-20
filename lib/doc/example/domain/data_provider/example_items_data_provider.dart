import 'package:voice_message/doc/example/domain/model/example_item.dart';

class ExampleItemsPage {
  const ExampleItemsPage({
    required this.items,
    required this.hasMore,
  });

  final List<ExampleItem> items;
  final bool hasMore;
}

/// Абстракция над источником данных.
///
/// Паттерн:
/// - только I/O, никакой бизнес-логики
/// - возвращает `AppResponse<T>` — ошибки через тип, не исключения
abstract class ExampleItemsDataProvider {
  Future<AppResponse<ExampleItemsPage>> fetchItems({
    required String channelId,
    String? afterId,
    int? count,
  });

  Future<AppResponse<ExampleItem>> fetchItem({
    required String channelId,
    required String itemId,
  });
}
