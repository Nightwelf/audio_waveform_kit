part of 'example_items_bloc.dart';

/// Публичные и приватные события BLoC.
///
/// Паттерны:
/// - sealed base + Equatable
/// - `part of` — файл события не импортируется напрямую
/// - приватные события (_Prefix) для internal stream updates
/// - props только для полей, влияющих на дедупликацию
sealed class ExampleItemsEvent extends Equatable {
  const ExampleItemsEvent();

  @override
  List<Object?> get props => [];
}

// ─── Публичные события (вызываются из UI/роутера) ─────────────────────────

/// Загрузить первую страницу для channelId.
/// transformer: restartable() — новый chatId отменяет предыдущую загрузку.
class ExampleItemsEvent$Load extends ExampleItemsEvent {
  const ExampleItemsEvent$Load({required this.channelId});

  final String channelId;

  @override
  List<Object?> get props => [channelId];
}

/// Загрузить следующую страницу (пагинация вниз).
/// transformer: droppable() — повторный вызов во время загрузки игнорируется.
class ExampleItemsEvent$LoadMore extends ExampleItemsEvent {
  const ExampleItemsEvent$LoadMore();
}

/// Изменились метрики скролла — проверить, нужна ли пагинация.
/// transformer: sequential() — обрабатываем по очереди, не теряем события.
class ExampleItemsEvent$ScrollMetricsChanged extends ExampleItemsEvent {
  const ExampleItemsEvent$ScrollMetricsChanged({
    required this.pixels,
    required this.maxScrollExtent,
  });

  final double pixels;
  final double maxScrollExtent;

  @override
  List<Object?> get props => [pixels, maxScrollExtent];
}

// ─── Приватные события (только BLoC) ─────────────────────────────────────

/// Realtime: обновить список (новый/изменённый/удалённый элемент).
/// transformer: sequential() — изменения применяются строго по порядку.
class _ExampleItemsEvent$UpdateItems extends ExampleItemsEvent {
  const _ExampleItemsEvent$UpdateItems(this.items);

  final List<ExampleItem> items;

  @override
  List<Object?> get props => [items];
}

/// Realtime: соединение восстановлено — перезагрузить данные.
/// transformer: restartable() — повторный reconnect отменяет предыдущую загрузку.
class _ExampleItemsEvent$Reconnected extends ExampleItemsEvent {
  const _ExampleItemsEvent$Reconnected();
}

/// Realtime: соединение потеряно — заблокировать пагинацию.
class _ExampleItemsEvent$Disconnected extends ExampleItemsEvent {
  const _ExampleItemsEvent$Disconnected();
}
