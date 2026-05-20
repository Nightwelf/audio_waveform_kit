part of 'example_items_bloc.dart';

/// Sealed state с общей базой.
///
/// Паттерны:
/// - sealed базовый класс содержит ВСЕ shared-поля
/// - copyWith реализован через switch — каждый вариант получает нужные поля
/// - _sentinel для nullable поля в copyWith (отличает "не передано" от null)
/// - buildWhen — статический хелпер для BlocBuilder, избегает лишних rebuild
/// - Computed properties (displayItems) — вычисляются один раз через late final
sealed class ExampleItemsState extends Equatable {
  ExampleItemsState({
    required this.channelId,
    required List<ExampleItem> items,
    this.hasMore = false,
    this.paginationInFlight = false,
  }) : _items = items;

  final String channelId;
  final List<ExampleItem> _items;
  final bool hasMore;
  final bool paginationInFlight;

  /// Только незалённые элементы — вычисляется один раз.
  late final List<ExampleItem> displayItems =
      _items.whereType<ExampleItem$Content>().where((e) => !e.isDeleted).toList(growable: false);

  /// Избегаем rebuild, если изменились только поля, не влияющие на UI.
  static bool buildWhen(ExampleItemsState prev, ExampleItemsState curr) {
    if (prev.runtimeType != curr.runtimeType) return true;
    return prev._items != curr._items || prev.hasMore != curr.hasMore;
  }

  /// Паттерн _sentinel нужен только для nullable полей (чтобы отличить
  /// "не передано" от "явный null"). Для non-nullable bool используем bool?.
  ExampleItemsState copyWith({
    String? channelId,
    List<ExampleItem>? items,
    bool? hasMore,
    bool? paginationInFlight,
  }) {
    return switch (this) {
      ExampleItemsState$Loading() => ExampleItemsState$Loading(
          channelId: channelId ?? this.channelId,
          items: items ?? _items,
          hasMore: hasMore ?? this.hasMore,
          paginationInFlight: paginationInFlight ?? this.paginationInFlight,
        ),
      ExampleItemsState$Loaded() => ExampleItemsState$Loaded(
          channelId: channelId ?? this.channelId,
          items: items ?? _items,
          hasMore: hasMore ?? this.hasMore,
          paginationInFlight: paginationInFlight ?? this.paginationInFlight,
        ),
      ExampleItemsState$Error() => ExampleItemsState$Error(
          channelId: channelId ?? this.channelId,
          items: items ?? _items,
          hasMore: hasMore ?? this.hasMore,
          paginationInFlight: paginationInFlight ?? this.paginationInFlight,
          error: (this as ExampleItemsState$Error).error,
        ),
    };
  }

  @override
  List<Object?> get props => [channelId, _items, hasMore, paginationInFlight];
}

/// Идёт первичная загрузка.
class ExampleItemsState$Loading extends ExampleItemsState {
  ExampleItemsState$Loading({
    required super.channelId,
    super.items = const [],
    super.hasMore,
    super.paginationInFlight,
  });
}

/// Данные загружены, UI показывает список.
class ExampleItemsState$Loaded extends ExampleItemsState {
  ExampleItemsState$Loaded({
    required super.channelId,
    required super.items,
    super.hasMore,
    super.paginationInFlight,
  });
}

/// Ошибка загрузки.
class ExampleItemsState$Error extends ExampleItemsState {
  ExampleItemsState$Error({
    required super.channelId,
    super.items = const [],
    super.hasMore,
    super.paginationInFlight,
    this.error,
  });

  final String? error;

  @override
  List<Object?> get props => [...super.props, error];
}
