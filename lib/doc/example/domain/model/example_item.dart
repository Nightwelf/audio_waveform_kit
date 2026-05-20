import 'package:equatable/equatable.dart';

/// Доменная сущность — sealed-иерархия.
///
/// Паттерны:
/// - sealed базовый класс с общими полями
/// - variants с $ суффиксом
/// - copyWith на каждом варианте с _sentinel для nullable полей
/// - Equatable для сравнения в BLoC/State
sealed class ExampleItem extends Equatable {
  const ExampleItem({
    required this.id,
    required this.authorId,
    required this.createdAt,
  });

  final String id;
  final UserGUID? authorId;
  final DateTime createdAt;

  ExampleItem copyWith({String? id, UserGUID? authorId, DateTime? createdAt});

  @override
  List<Object?> get props => [id, authorId, createdAt];
}

/// Обычный элемент с пользовательским контентом.
class ExampleItem$Content extends ExampleItem {
  const ExampleItem$Content({
    required super.id,
    required super.authorId,
    required super.createdAt,
    required this.title,
    this.deletedBy,
  });

  final String title;

  /// null = не удалён; non-null = GUID или маркер причины удаления.
  final String? deletedBy;

  bool get isDeleted => deletedBy != null;

  @override
  ExampleItem$Content copyWith({
    String? id,
    UserGUID? authorId,
    DateTime? createdAt,
    String? title,
    // _sentinel отличает "не передано" от явного null — паттерн для nullable copyWith.
    Object? deletedBy = _sentinel,
  }) =>
      ExampleItem$Content(
        id: id ?? this.id,
        authorId: authorId ?? this.authorId,
        createdAt: createdAt ?? this.createdAt,
        title: title ?? this.title,
        deletedBy: identical(deletedBy, _sentinel) ? this.deletedBy : deletedBy as String?,
      );

  @override
  List<Object?> get props => [...super.props, title, deletedBy];

  static const _sentinel = Object();
}

/// Системный элемент (служебное уведомление).
class ExampleItem$System extends ExampleItem {
  const ExampleItem$System({
    required super.id,
    required super.authorId,
    required super.createdAt,
    required this.text,
  });

  final String text;

  @override
  ExampleItem$System copyWith({
    String? id,
    UserGUID? authorId,
    DateTime? createdAt,
    String? text,
  }) =>
      ExampleItem$System(
        id: id ?? this.id,
        authorId: authorId ?? this.authorId,
        createdAt: createdAt ?? this.createdAt,
        text: text ?? this.text,
      );

  @override
  List<Object?> get props => [...super.props, text];
}
