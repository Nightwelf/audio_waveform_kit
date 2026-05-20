# Codestyle — satel-vks-flutter

Правила выведены из кода проекта. Эталонная реализация: `lib/doc/example/`.

---

## 1. Именование

| Сущность | Паттерн | Пример |
|---|---|---|
| Файл | `snake_case.dart` | `chat_messages_bloc.dart` |
| Sealed variant | `ClassName$Variant` | `ChatMessagesState$Loading` |
| Приватный event | `_ClassName$Variant` | `_ChatMessagesEvent$Reconnected` |
| Реализация | `InterfaceImpl` | `ChatMessagesRepositoryImpl` |
| Конфиг фичи | `FeatureConfig` | `ChatMessagesConfig` |
| Тег логирования | `'[ClassName]'` | `final _tag = '[ChatMessagesBloc]'` |

Sealed variants — всегда с `$`. Никаких `Loading`, `Loaded` без префикса класса.

---

## 2. Структура фичи``
``
```
{feature}/
├── config.dart                   # Константы и лог-хелпер
├── {feature}_scope.dart          # DI-дерево
├── domain/
│   ├── model/                    # Sealed-сущности и action-типы
│   ├── data_provider/            # Abstract DataProvider
│   └── repository/               # Abstract Repository
├── data/
│   ├── data_provider/            # HTTP-реализация
│   └── repository/               # Impl с бизнес-логикой и стримами
└── presentation/
    ├── bloc/{name}/
    │   ├── {name}_bloc.dart      # BLoC + part-директивы
    │   ├── {name}_event.dart     # part of bloc
    │   └── {name}_state.dart     # part of bloc
    └── pages/
        └── {name}_page.dart      # Один виджет — один файл
```

---

## 3. Config

```dart
abstract class ExampleConfig {
  ExampleConfig._();           // Приватный конструктор — нельзя создать экземпляр

  static const bool logs = true;
  static const int pageSize = 50;
  static const Duration saveReadPositionDebounce = Duration(milliseconds: 2000);

  static void log(String message, {StackTrace? trace}) =>
      logs ? (trace != null ? Log.error(message, trace: trace) : Log(message)) : null;
}
```

---

## 4. Sealed-модели

### Базовый паттерн

```dart
sealed class ExampleItem extends Equatable {
  const ExampleItem({required this.id, required this.authorId});

  final String id;
  final String authorId;

  ExampleItem copyWith({String? id, String? authorId});

  @override
  List<Object?> get props => [id, authorId];
}

class ExampleItem$Content extends ExampleItem {
  const ExampleItem$Content({
    required super.id,
    required super.authorId,
    required this.title,
    this.deletedBy,         // nullable — нужен _sentinel в copyWith
  });

  final String title;
  final String? deletedBy;

  bool get isDeleted => deletedBy != null;

  @override
  ExampleItem$Content copyWith({
    String? id,
    String? authorId,
    String? title,
    Object? deletedBy = _sentinel,   // отличает "не передано" от явного null
  }) =>
      ExampleItem$Content(
        id: id ?? this.id,
        authorId: authorId ?? this.authorId,
        title: title ?? this.title,
        deletedBy: identical(deletedBy, _sentinel) ? this.deletedBy : deletedBy as String?,
      );

  static const _sentinel = Object();

  @override
  List<Object?> get props => [...super.props, title, deletedBy];
}
```

### Правила

- `_sentinel` нужен только для **nullable** полей в `copyWith` — отличает "не передано" от `null`.
- Для non-nullable полей в `copyWith` используем обычный `T?`.
- `props` в базовом классе + `[...super.props, ...]` в вариантах.
- Computed properties — `bool get isDeleted => deletedBy != null`, не методы.

---

## 5. Action-типы (Realtime)

```dart
// Sealed без общего payload — каждый вариант несёт только нужные данные.
sealed class ExampleItemAction extends Equatable {
  const ExampleItemAction();
  @override
  List<Object?> get props => [];
}

class ExampleItemAction$Created extends ExampleItemAction {
  const ExampleItemAction$Created({required this.item});
  final ExampleItem item;
  @override
  List<Object?> get props => [item];
}

class ExampleItemAction$Deleted extends ExampleItemAction {
  const ExampleItemAction$Deleted({required this.itemId});
  final String itemId;
  @override
  List<Object?> get props => [itemId];
}

// Маркерные классы без полей
class ExampleItemAction$Reconnected extends ExampleItemAction {
  const ExampleItemAction$Reconnected();
}

class ExampleItemAction$Disconnected extends ExampleItemAction {
  const ExampleItemAction$Disconnected();
}
```

---

## 6. DataProvider

```dart
// Интерфейс — только I/O, никакой логики
abstract class ExampleItemsDataProvider {
  Future<AppResponse<(List<ExampleItem> items, bool hasMore)>> fetchItems({
    required String channelId,
    String? afterId,
    int? count,
  });
}

// Реализация
class ExampleItemsDataProviderImpl implements ExampleItemsDataProvider {
  ExampleItemsDataProviderImpl({required ApiHttpClient httpClient})
      : _httpClient = httpClient as ApiHttpClientRtu;  // всегда cast к Rtu

  final ApiHttpClientRtu _httpClient;

  @override
  Future<AppResponse<(List<ExampleItem> items, bool hasMore)>> fetchItems({...}) async {
    try {
      final response = await _httpClient.publicApiDio.get<Map<String, dynamic>>(
        '/channels/$channelId/items',
        queryParameters: {
          if (afterId != null) 'afterId': afterId,
          if (count != null) 'count': count,
        },
      );
      final data = response.data ?? {};
      final items = (data['items'] as List).cast<Map<String, dynamic>>().map(_parse).toList();
      return AppResponse$Success(data: (items, data['hasMore'] as bool? ?? false));
    } catch (e) {
      return AppResponse$Error(error: ResponseError.unknown());
    }
  }

  // Парсинг JSON — switch по type-полю → exhaustive mapping на sealed variants
  ExampleItem _parse(Map<String, dynamic> json) => switch (json['type'] as String?) {
        'content' => ExampleItem$Content(id: json['id'] as String, ...),
        'system'  => ExampleItem$System(id: json['id'] as String, ...),
        _         => throw FormatException('Unknown type: ${json['type']}'),
      };
}
```

### Правила

- `ApiHttpClient` принимается в конструктор, кастуется к `ApiHttpClientRtu` — всегда.
- Возвращает `AppResponse<T>`, никогда не бросает исключения выше `try/catch`.
- Record-тип `(List<T>, bool)` вместо wrapper-класса для простых пар значений.

---

## 7. Repository

```dart
// Интерфейс
abstract class ExampleItemsRepository {
  Stream<ExampleItemAction> get realtime;   // broadcast-стрим доменных действий

  Future<AppResponse<List<ExampleItem>>> getItems({
    required String channelId,
    String? afterId,
    int count,
  });

  Future<void> dispose();   // обязателен при наличии стримов
}

// Реализация
class ExampleItemsRepositoryImpl implements ExampleItemsRepository {
  ExampleItemsRepositoryImpl({
    required ExampleItemsDataProvider dataProvider,
    required ChatsRealtimeRepository realtimeRepository,
  })  : _dataProvider = dataProvider,
        _realtimeRepository = realtimeRepository {
    // Подписки в конструкторе — данные начинают поступать немедленно
    _eventsSubscription = _realtimeRepository.events.listen(_handleRealtimeEvent);
    _connectionSubscription = _realtimeRepository.connectionState.listen(_handleConnectionState);
  }

  final _tag = '[ExampleItemsRepository]';
  final ExampleItemsDataProvider _dataProvider;
  final ChatsRealtimeRepository _realtimeRepository;

  final _realtime = StreamController<ExampleItemAction>.broadcast();
  StreamSubscription<ChatsRealtimeEvent>? _eventsSubscription;
  StreamSubscription<ChatsRealtimeConnectionState>? _connectionSubscription;
  bool _wasConnected = false;    // первый connect != reconnect

  @override
  Stream<ExampleItemAction> get realtime => _realtime.stream;

  @override
  Future<void> dispose() async {
    await _eventsSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _realtime.close();
  }

  void _handleConnectionState(ChatsRealtimeConnectionState state) {
    switch (state) {
      case ChatsRealtimeConnectionState.connected:
        if (_wasConnected) _realtime.add(const ExampleItemAction$Reconnected());
        _wasConnected = true;
      case ChatsRealtimeConnectionState.disconnected:
      case ChatsRealtimeConnectionState.reconnecting:
      case ChatsRealtimeConnectionState.error:
        if (_wasConnected) _realtime.add(const ExampleItemAction$Disconnected());
      case ChatsRealtimeConnectionState.connecting:
        break;
    }
  }

  void _handleRealtimeEvent(ChatsRealtimeEvent event) {
    switch (event) {
      case ChatsRealtimeEvent$MessageSent(:final message):
        final item = _mapToItem(message);
        if (item != null) _realtime.add(ExampleItemAction$Created(item: item));
      case ChatsRealtimeEvent$MessageDeleted(:final messageId):
        _realtime.add(ExampleItemAction$Deleted(itemId: messageId));
      case _:
        break;   // новые типы RTU-событий не ломают фичу
    }
  }

  ExampleItem? _mapToItem(ChatMessage message) => switch (message) {
        UserMessage(:final base, :final content) => ExampleItem$Content(
            id: base.id, authorId: base.author, createdAt: base.createdAt, title: content,
          ),
        _ => null,
      };
}
```

### Правила

- `dispose()` закрывает **все** `StreamSubscription` и `StreamController`.
- `broadcast()` — стрим поддерживает несколько слушателей (BLoC + тесты).
- `_wasConnected`: первое `connected` не эмитит `Reconnected`, только последующие.
- `case _: break` в обработчике событий — явное игнорирование неизвестных типов.
- Маппинг RTU-моделей в доменные — только в репозитории, не в BLoC.

---

## 8. BLoC

### Event

```dart
part of 'example_items_bloc.dart';

sealed class ExampleItemsEvent extends Equatable {
  const ExampleItemsEvent();
  @override
  List<Object?> get props => [];
}

// Публичные события — вызываются из UI
class ExampleItemsEvent$Load extends ExampleItemsEvent {
  const ExampleItemsEvent$Load({required this.channelId});
  final String channelId;
  @override
  List<Object?> get props => [channelId];
}

class ExampleItemsEvent$LoadMore extends ExampleItemsEvent {
  const ExampleItemsEvent$LoadMore();
}

// Приватные события — только внутри BLoC (stream updates)
class _ExampleItemsEvent$UpdateItems extends ExampleItemsEvent {
  const _ExampleItemsEvent$UpdateItems(this.items);
  final List<ExampleItem> items;
  @override
  List<Object?> get props => [items];
}

class _ExampleItemsEvent$Reconnected extends ExampleItemsEvent {
  const _ExampleItemsEvent$Reconnected();
}
```

### State

```dart
part of 'example_items_bloc.dart';

sealed class ExampleItemsState extends Equatable {
  ExampleItemsState({
    required this.channelId,
    required List<ExampleItem> items,
    this.hasMore = false,
    this.paginationInFlight = false,
  }) : _items = items;

  final String channelId;
  final List<ExampleItem> _items;   // приватный список
  final bool hasMore;
  final bool paginationInFlight;

  // Вычисляется один раз — не в build()
  late final List<ExampleItem> displayItems =
      _items.whereType<ExampleItem$Content>().where((e) => !e.isDeleted).toList(growable: false);

  // Управляет rebuild BlocBuilder — исключает лишние перерисовки
  static bool buildWhen(ExampleItemsState prev, ExampleItemsState curr) {
    if (prev.runtimeType != curr.runtimeType) return true;
    return prev._items != curr._items || prev.hasMore != curr.hasMore;
  }

  // copyWith через switch — каждый вариант получает нужные поля
  ExampleItemsState copyWith({
    String? channelId,
    List<ExampleItem>? items,
    bool? hasMore,
    bool? paginationInFlight,       // bool? достаточно для non-nullable
  }) =>
      switch (this) {
        ExampleItemsState$Loading() => ExampleItemsState$Loading(
            channelId: channelId ?? this.channelId,
            items: items ?? _items,
            hasMore: hasMore ?? this.hasMore,
            paginationInFlight: paginationInFlight ?? this.paginationInFlight,
          ),
        ExampleItemsState$Loaded() => ExampleItemsState$Loaded(...),
        ExampleItemsState$Error()  => ExampleItemsState$Error(...),
      };

  @override
  List<Object?> get props => [channelId, _items, hasMore, paginationInFlight];
}

class ExampleItemsState$Loading extends ExampleItemsState { ... }
class ExampleItemsState$Loaded  extends ExampleItemsState { ... }
class ExampleItemsState$Error   extends ExampleItemsState {
  ExampleItemsState$Error({..., this.error});
  final String? error;
  @override
  List<Object?> get props => [...super.props, error];
}
```

### Bloc

```dart
class ExampleItemsBloc extends Bloc<ExampleItemsEvent, ExampleItemsState> {
  ExampleItemsBloc({required ExampleItemsRepository repository})
      : _repository = repository,
        super(ExampleItemsState$Loading(channelId: '')) {
    on<ExampleItemsEvent$Load>(_onLoad,           transformer: restartable());
    on<ExampleItemsEvent$LoadMore>(_onLoadMore,   transformer: droppable());
    on<ExampleItemsEvent$ScrollMetricsChanged>(_onScroll, transformer: sequential());
    on<_ExampleItemsEvent$UpdateItems>(_onUpdate, transformer: sequential());
    on<_ExampleItemsEvent$Reconnected>(_onReconnected, transformer: restartable());
    on<_ExampleItemsEvent$Disconnected>(_onDisconnected, transformer: droppable());

    _realtimeSubscription = _repository.realtime.listen(_handleRealtimeAction);
  }

  final ExampleItemsRepository _repository;
  StreamSubscription<ExampleItemAction>? _realtimeSubscription;
  bool _paginationBlocked = false;

  Future<void> _onLoad(ExampleItemsEvent$Load event, Emitter<ExampleItemsState> emit) async {
    emit(ExampleItemsState$Loading(channelId: event.channelId));
    final response = await _repository.getItems(channelId: event.channelId);
    // Проверка после await — restartable мог отменить этот handler
    if (event.channelId != state.channelId) return;
    if (response.isError) {
      emit(ExampleItemsState$Error(channelId: event.channelId, error: response.error.code.text));
      return;
    }
    emit(ExampleItemsState$Loaded(channelId: event.channelId, items: response.data));
  }

  void _handleRealtimeAction(ExampleItemAction action) {
    final current = state;
    if (current is! ExampleItemsState$Loaded) return;
    switch (action) {
      case ExampleItemAction$Created(:final item):
        add(_ExampleItemsEvent$UpdateItems([item, ...current._items]));
      case ExampleItemAction$Reconnected():
        add(const _ExampleItemsEvent$Reconnected());
      case ExampleItemAction$Disconnected():
        add(const _ExampleItemsEvent$Disconnected());
      // ...
    }
  }

  @override
  Future<void> close() {
    _realtimeSubscription?.cancel();
    return super.close();
  }
}
```

### Правила BLoC

| Transformer | Когда использовать |
|---|---|
| `restartable()` | Загрузка (новый параметр отменяет предыдущую), reconnect |
| `droppable()` | Пагинация (повтор во время выполнения игнорируется), disconnect |
| `sequential()` | Scroll-метрики, internal updates (не теряем, обрабатываем по очереди) |

- `part of` — event и state не импортируются снаружи, только через bloc.
- Приватные `_Event$` — изменения из stream-коллбэков всегда через `add()`, не через прямой emit.
- После `await` проверяем `state.channelId == event.channelId` — handler мог быть отменён.
- `_paginationBlocked` — флаг на время RTU-disconnected, снимается при reconnected.
- Никаких публичных полей на BLoC — только `add()` и `state`.

---

## 9. DI / Scope

```dart
class ExampleScope extends StatelessWidget {
  const ExampleScope({super.key, required this.httpClient, required this.child});

  final ApiHttpClient httpClient;   // внешние зависимости через конструктор
  final Widget child;

  // Навигационный хелпер — вместо goNamed в каждом виджете
  static void goToItems(BuildContext context, String channelId) {
    context.goNamed(ExampleItemsPage.name, pathParameters: {'channelId': channelId});
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ExampleItemsRepository>(
            create: (context) => ExampleItemsRepositoryImpl(
              dataProvider: ExampleItemsDataProviderImpl(httpClient: httpClient), // inline
              realtimeRepository: context.read<ChatsRealtimeRepository>(), // из родительского scope
            ),
            dispose: (repo) => repo.dispose(),  // обязателен для стримов
          ),
          // lazy: false — для сервисов, которые должны стартовать немедленно
          RepositoryProvider<SomeService>(
            create: (context) => SomeServiceImpl(),
            lazy: false,
          ),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ExampleItemsBloc>(
              create: (context) => ExampleItemsBloc(
                repository: context.read<ExampleItemsRepository>(),
              ),
            ),
          ],
          child: child,
        ),
      );
}
```

### Правила

- Scope принимает внешние зависимости через конструктор — не через `context.read` из build.
- DataProvider создаётся inline в `create:` репозитория — отдельный провайдер не нужен.
- `dispose:` обязателен для любого репозитория с `StreamSubscription` или `StreamController`.
- `lazy: false` — только для сервисов, требующих немедленной инициализации (например, realtime).
- `context.read<T>()` между провайдерами работает, если провайдер объявлен выше по списку.
- BLoC в scope — если нужен нескольким страницам. Для одного маршрута — `NavigationConfig.providers`.

---

## 10. UI / Widgets

```dart
// Один виджет — один файл. StatelessWidget + BlocBuilder, не StatefulWidget.
class ExampleItemsPage extends StatelessWidget {
  const ExampleItemsPage({super.key, required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context) {
    // context.read() в build — только для вызовов вне rebuild-цикла
    context.read<ExampleItemsBloc>().add(ExampleItemsEvent$Load(channelId: channelId));

    return Scaffold(
      body: BlocBuilder<ExampleItemsBloc, ExampleItemsState>(
        buildWhen: ExampleItemsState.buildWhen,   // контроль rebuild
        builder: (context, state) => switch (state) {
          ExampleItemsState$Loading()            => const CircularProgressIndicator(),
          ExampleItemsState$Error(:final error)  => Text(error ?? ''),
          ExampleItemsState$Loaded()             => _ItemsList(state: state),
        },
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  const _ItemsList({required this.state});
  final ExampleItemsState$Loaded state;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          // context.read() в callback — корректно, это не build-метод
          context.read<ExampleItemsBloc>().add(
                ExampleItemsEvent$ScrollMetricsChanged(
                  pixels: notification.metrics.pixels,
                  maxScrollExtent: notification.metrics.maxScrollExtent,
                ),
              );
        }
        return false;
      },
      child: ListView.builder(...),
    );
  }
}
```

### Правила

- `context.read()` — только вне `build`. В `build` — только `context.watch()`.
- `context.read()` допустим в `build` **только** для однократных вызовов (`add` при первом построении).
- `BlocBuilder.buildWhen` — всегда указывать если в state есть поля, не влияющие на UI.
- `BlocBuilder` и `BlocListener` разделять — Builder для UI, Listener для side effects.
- `const` везде, где возможно.
- `switch` по sealed-вариантам вместо `if (state is ...)`.
- Не использовать `!` — всегда проверять на null.
- `if (!mounted) return;` перед `setState()` в async-коллбэках.

---

## 11. Общие правила Dart

```dart
// Коллекции — не == напрямую
const eq = ListEquality();
eq.equals(listA, listB);   // не listA == listB

// Async dispose
Future<void> dispose() async {
  await subscription?.cancel();
  await controller.close();   // порядок: сначала subscription, потом controller
}

// Nullable check вместо !
final value = map[key];
if (value == null) return;
use(value);   // не map[key]!

// Record-типы для пар
Future<(List<T>, bool)> fetchPage();   // не wrapper-класс

// Switch exhaustive по sealed — компилятор проверит полноту
switch (action) {
  case Action$A(): ...
  case Action$B(): ...
  // забыли Action$C — compile error
}
```
