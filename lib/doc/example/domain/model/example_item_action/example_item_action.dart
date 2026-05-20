import 'package:equatable/equatable.dart';
import 'package:voice_message/doc/example/domain/model/example_item.dart';

/// Доменные действия из realtime-потока.
///
/// Репозиторий трансформирует сырые RTU-события (ChatsRealtimeEvent)
/// в эти типы. BLoC обрабатывает их через switch/pattern matching.
///
/// Паттерн: sealed без chatId на базе — каждый тип несёт только нужные данные.
/// Reconnected/Disconnected — маркерные классы без полей.
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

class ExampleItemAction$Changed extends ExampleItemAction {
  const ExampleItemAction$Changed({required this.item});

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

class ExampleItemAction$Reconnected extends ExampleItemAction {
  const ExampleItemAction$Reconnected();
}

class ExampleItemAction$Disconnected extends ExampleItemAction {
  const ExampleItemAction$Disconnected();
}
