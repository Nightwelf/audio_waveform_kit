import 'dart:async';

import 'package:voice_message/app_rtu/chats/chat_messages/domain/model/message/chat_messages.dart';
import 'package:voice_message/app_rtu/core/data/model/response.dart';
import 'package:voice_message/app_rtu/realtime/domain/model/realtime_connection_state.dart';
import 'package:voice_message/app_rtu/realtime/domain/model/realtime_event.dart';
import 'package:voice_message/app_rtu/realtime/domain/repository/realtime_repository.dart';
import 'package:voice_message/doc/example/config.dart';
import 'package:voice_message/doc/example/domain/data_provider/example_items_data_provider.dart';
import 'package:voice_message/doc/example/domain/model/example_item.dart';
import 'package:voice_message/doc/example/domain/model/example_item_action/example_item_action.dart';
import 'package:voice_message/doc/example/domain/repository/example_items_repository.dart';

/// Реализация репозитория с realtime-интеграцией.
///
/// Ключевые паттерны:
/// 1. Подписки на RTU в конструкторе — данные начинают поступать немедленно.
/// 2. Трансформация RTU-событий (RealtimeEvent) в доменные действия (ExampleItemAction).
/// 3. Connection state → Reconnected/Disconnected для BLoC.
/// 4. broadcast() стрим — поддерживает несколько слушателей.
/// 5. dispose() отменяет ВСЕ подписки и закрывает стрим.
class ExampleItemsRepositoryImpl implements ExampleItemsRepository {
  ExampleItemsRepositoryImpl({
    required ExampleItemsDataProvider dataProvider,
    required RealtimeRepository realtimeRepository,
  })  : _dataProvider = dataProvider,
        _realtimeRepository = realtimeRepository {
    _eventsSubscription = _realtimeRepository.events.listen(_handleRealtimeEvent);
    _connectionSubscription = _realtimeRepository.connectionState.listen(_handleConnectionState);
  }

  final _tag = '[ExampleItemsRepository]';

  final ExampleItemsDataProvider _dataProvider;
  final RealtimeRepository _realtimeRepository;

  // broadcast() — несколько слушателей (BLoC + тесты).
  final _realtime = StreamController<ExampleItemAction>.broadcast();
  StreamSubscription<RealtimeEvent>? _eventsSubscription;
  StreamSubscription<RealtimeConnectionState>? _connectionSubscription;
  bool _wasConnected = false;

  @override
  Stream<ExampleItemAction> get realtime => _realtime.stream;

  // ─── Публичные методы ──────────────────────────────────────────────────────

  @override
  Future<AppResponse<List<ExampleItem>>> getItems({
    required String channelId,
    String? afterId,
    int count = ExampleConfig.pageSize,
  }) async {
    ExampleConfig.log('$_tag getItems channelId=$channelId afterId=$afterId');
    final response = await _dataProvider.fetchItems(
      channelId: channelId,
      afterId: afterId,
      count: count,
    );
    if (!response.isSuccess) {
      return AppResponse$Error(error: response.error);
    }
    final page = response.data;
    return AppResponse$Success(data: page.items);
  }

  @override
  Future<AppResponse<ExampleItem>> getItem({
    required String channelId,
    required String itemId,
  }) =>
      _dataProvider.fetchItem(channelId: channelId, itemId: itemId);

  // ─── Dispose ───────────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    await _eventsSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _realtime.close();
  }

  // ─── Realtime: connection state ────────────────────────────────────────────

  /// Трансформирует connection state в доменные события.
  ///
  /// Паттерн: _wasConnected позволяет отличить первое подключение
  /// от переподключения после разрыва — первый connected НЕ даёт Reconnected.
  void _handleConnectionState(RealtimeConnectionState state) {
    switch (state) {
      case RealtimeConnectionState.connected:
        if (_wasConnected) {
          _realtime.add(const ExampleItemAction$Reconnected());
        }
        _wasConnected = true;
      case RealtimeConnectionState.disconnected:
      case RealtimeConnectionState.reconnecting:
      case RealtimeConnectionState.error:
        if (_wasConnected) {
          _realtime.add(const ExampleItemAction$Disconnected());
        }
      case RealtimeConnectionState.connecting:
        break;
    }
  }

  // ─── Realtime: события ────────────────────────────────────────────────────

  /// Фильтрует и трансформирует RTU-события в доменные действия.
  ///
  /// Паттерн: каждый репозиторий обрабатывает только нужные ему типы.
  /// Неизвестные события игнорируются без ошибок (case _: break).
  void _handleRealtimeEvent(RealtimeEvent event) {
    switch (event) {
      case RealtimeEvent$MessageSent(:final message):
        ExampleConfig.log('$_tag _handleRealtimeEvent: MessageSent id=${message.id}');
        // Маппинг RTU-модели (ChatMessage) в доменную модель этой фичи (ExampleItem).
        final item = _mapToItem(message);
        if (item != null) {
          _realtime.add(ExampleItemAction$Created(item: item));
        }
      case RealtimeEvent$MessageChanged(:final message):
        ExampleConfig.log('$_tag _handleRealtimeEvent: MessageChanged id=${message.id}');
        final item = _mapToItem(message);
        if (item != null) {
          _realtime.add(ExampleItemAction$Changed(item: item));
        }
      case RealtimeEvent$MessageDeleted(:final messageId):
        ExampleConfig.log('$_tag _handleRealtimeEvent: MessageDeleted id=$messageId');
        _realtime.add(ExampleItemAction$Deleted(itemId: messageId));
      case _:
        // Новые типы RTU-событий не ломают фичу.
        break;
    }
  }

  /// Маппинг RTU-модели в доменную модель фичи.
  ///
  /// Паттерн: nullable возврат — репозиторий решает, какие варианты релевантны.
  ExampleItem? _mapToItem(ChatMessage message) => switch (message) {
        UserMessage(:final base, :final content) => ExampleItem$Content(
            id: base.id,
            authorId: base.author,
            createdAt: base.createdAt,
            title: content,
          ),
        _ => null, // Системные сообщения этой фиче не нужны.
      };
}
