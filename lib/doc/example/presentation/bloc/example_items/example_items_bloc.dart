import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/doc/example/config.dart';
import 'package:voice_message/doc/example/domain/model/example_item.dart';
import 'package:voice_message/doc/example/domain/model/example_item_action/example_item_action.dart';
import 'package:voice_message/doc/example/domain/repository/example_items_repository.dart';

part 'example_items_event.dart';
part 'example_items_state.dart';

/// BLoC фичи с realtime-интеграцией и пагинацией.
///
/// Ключевые паттерны:
/// 1. Transformers: restartable / droppable / sequential по смыслу события.
/// 2. StreamSubscription подписывается в конструкторе, отменяется в close().
/// 3. Realtime-события → приватные internal events → sequential обработка.
/// 4. _paginationBlocked при disconnected — разблокируется при reconnected.
/// 5. Reconnected перезагружает данные — не добавляет к существующим.
/// 6. Нет публичных полей — вся логика в BLoC/State.
class ExampleItemsBloc extends Bloc<ExampleItemsEvent, ExampleItemsState> {
  ExampleItemsBloc({required ExampleItemsRepository repository})
      : _repository = repository,
        super(ExampleItemsState$Loading(channelId: '')) {
    // Порядок регистрации важен: публичные → приватные.
    on<ExampleItemsEvent$Load>(_onLoad, transformer: restartable());
    on<ExampleItemsEvent$LoadMore>(_onLoadMore, transformer: droppable());
    on<ExampleItemsEvent$ScrollMetricsChanged>(
      _onScrollMetricsChanged,
      transformer: sequential(),
    );
    on<_ExampleItemsEvent$UpdateItems>(_onUpdateItems, transformer: sequential());
    on<_ExampleItemsEvent$Reconnected>(_onReconnected, transformer: restartable());
    on<_ExampleItemsEvent$Disconnected>(_onDisconnected, transformer: droppable());

    _realtimeSubscription = _repository.realtime.listen(_handleRealtimeAction);
  }

  static const _tag = '[ExampleItemsBloc]';
  static const _edgeTriggerThreshold = 100.0;

  final ExampleItemsRepository _repository;
  StreamSubscription<ExampleItemAction>? _realtimeSubscription;
  bool _paginationBlocked = false;

  // ─── Handlers ─────────────────────────────────────────────────────────────

  Future<void> _onLoad(
    ExampleItemsEvent$Load event,
    Emitter<ExampleItemsState> emit,
  ) async {
    emit(ExampleItemsState$Loading(channelId: event.channelId));
    final response = await _repository.getItems(channelId: event.channelId);
    // Проверяем chatId после await — restartable мог отменить этот handler.
    if (event.channelId != state.channelId) return;
    if (response.isError) {
      emit(ExampleItemsState$Error(
        channelId: event.channelId,
        error: response.error.code.text,
      ));
      return;
    }
    emit(ExampleItemsState$Loaded(
      channelId: event.channelId,
      items: response.data,
    ));
  }

  Future<void> _onLoadMore(
    ExampleItemsEvent$LoadMore event,
    Emitter<ExampleItemsState> emit,
  ) async {
    final current = state;
    if (current is! ExampleItemsState$Loaded) return;
    if (!current.hasMore || current.paginationInFlight || _paginationBlocked) return;

    emit(current.copyWith(paginationInFlight: true));
    final lastId = current.displayItems.lastOrNull?.id;
    final response = await _repository.getItems(
      channelId: current.channelId,
      afterId: lastId,
    );
    final after = state;
    // Проверяем состояние после await — могло измениться.
    if (after is! ExampleItemsState$Loaded || after.channelId != current.channelId) return;

    if (response.isError) {
      ExampleConfig.log('$_tag _onLoadMore: ${response.error.code.text}');
      emit(after.copyWith(paginationInFlight: false));
      return;
    }
    emit(ExampleItemsState$Loaded(
      channelId: after.channelId,
      items: [...after.displayItems, ...response.data],
      hasMore: response.data.length >= ExampleConfig.pageSize,
    ));
  }

  void _onScrollMetricsChanged(
    ExampleItemsEvent$ScrollMetricsChanged event,
    Emitter<ExampleItemsState> emit,
  ) {
    if (state is! ExampleItemsState$Loaded) return;
    final current = state as ExampleItemsState$Loaded;
    if (current.paginationInFlight || _paginationBlocked) return;

    final nearBottom = event.pixels >= event.maxScrollExtent - _edgeTriggerThreshold;
    if (nearBottom && current.hasMore) {
      add(const ExampleItemsEvent$LoadMore());
    }
  }

  void _onUpdateItems(
    _ExampleItemsEvent$UpdateItems event,
    Emitter<ExampleItemsState> emit,
  ) {
    if (state is! ExampleItemsState$Loaded) return;
    final current = state as ExampleItemsState$Loaded;
    emit(current.copyWith(items: event.items));
  }

  void _onDisconnected(
    _ExampleItemsEvent$Disconnected event,
    Emitter<ExampleItemsState> emit,
  ) {
    _paginationBlocked = true;
  }

  Future<void> _onReconnected(
    _ExampleItemsEvent$Reconnected event,
    Emitter<ExampleItemsState> emit,
  ) async {
    _paginationBlocked = false;
    final current = state;
    if (current is! ExampleItemsState$Loaded || current.channelId.isEmpty) return;

    // При переподключении перезагружаем с начала — не добавляем поверх.
    final response = await _repository.getItems(channelId: current.channelId);
    final after = state;
    if (after is! ExampleItemsState$Loaded || after.channelId != current.channelId) return;
    if (response.isError) {
      ExampleConfig.log('$_tag _onReconnected: ${response.error.code.text}');
      return;
    }
    emit(ExampleItemsState$Loaded(
      channelId: after.channelId,
      items: response.data,
      hasMore: after.hasMore,
    ));
  }

  // ─── Realtime ──────────────────────────────────────────────────────────────

  /// Обрабатывает доменные действия из realtime-потока.
  ///
  /// Паттерн: прямые изменения state делаем через add(internal_event),
  /// чтобы не обходить transformer-логику.
  void _handleRealtimeAction(ExampleItemAction action) {
    final current = state;
    if (current is! ExampleItemsState$Loaded) return;

    switch (action) {
      case ExampleItemAction$Created(:final item):
        // Новый элемент добавляем в начало списка.
        add(_ExampleItemsEvent$UpdateItems([item, ...current._items]));

      case ExampleItemAction$Changed(:final item):
        // Обновляем элемент на месте — сохраняем порядок.
        final updated = current._items.map((e) => e.id == item.id ? item : e).toList(growable: false);
        add(_ExampleItemsEvent$UpdateItems(updated));

      case ExampleItemAction$Deleted(:final itemId):
        // Помечаем как удалённый (soft delete) вместо удаления из списка.
        final updated = current._items.map((e) {
          if (e.id == itemId && e is ExampleItem$Content) {
            return e.copyWith(deletedBy: 'realtime');
          }
          return e;
        }).toList(growable: false);
        add(_ExampleItemsEvent$UpdateItems(updated));

      case ExampleItemAction$Reconnected():
        add(const _ExampleItemsEvent$Reconnected());

      case ExampleItemAction$Disconnected():
        add(const _ExampleItemsEvent$Disconnected());
    }
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> close() {
    _realtimeSubscription?.cancel();
    return super.close();
  }
}
