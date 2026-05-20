import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/doc/example/data/data_provider/example_items_data_provider_impl.dart';
import 'package:voice_message/doc/example/data/repository/example_items_repository_impl.dart';
import 'package:voice_message/doc/example/domain/repository/example_items_repository.dart';
import 'package:voice_message/doc/example/presentation/bloc/example_items/example_items_bloc.dart';

import 'data/data_provider/example_items_data_provider_impl.dart';
import 'data/repository/example_items_repository_impl.dart';
import 'domain/repository/example_items_repository.dart';

/// DI-scope фичи: StatelessWidget с MultiRepositoryProvider + MultiBlocProvider.
///
/// Паттерны:
/// - Scope получает внешние зависимости через конструктор (не context.read).
/// - DataProvider создаётся inline внутри create: репозитория.
/// - dispose: обязателен для репозиториев со стримами/StreamSubscription.
/// - lazy: false для сервисов, которые должны стартовать немедленно.
/// - context.read<T>() между провайдерами допустим, если порядок правильный.
/// - BLoC создаётся через BlocProvider в NavigationConfig.providers или здесь,
///   если он нужен для всего поддерева (не только для одной страницы).
// ignore_for_file: unintended_html_in_doc_comment
///
/// ВАЖНО: Если BLoC нужен только для одного маршрута — выносим его в
/// NavigationConfig.providers (см. chats/config.dart), а не в scope.
class ExampleScope extends StatelessWidget {
  const ExampleScope({
    required this.httpClient,
    required this.child,
    super.key,
  });

  final ApiHttpClient httpClient;
  final Widget child;

  /// Навигационный хелпер — удобнее, чем писать goNamed в каждом виджете.
  static void goToItems(BuildContext context, String channelId) {
    // context.goNamed(ExampleItemsPage.name, pathParameters: {'channelId': channelId});
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<ExampleItemsRepository>(
        create: (context) => ExampleItemsRepositoryImpl(
          // DataProvider создаётся прямо здесь — не нужен отдельный провайдер.
          dataProvider: ExampleItemsDataProviderImpl(httpClient: httpClient),
          // RealtimeRepository уже зарегистрирован выше в дереве (ChatsScope).
          realtimeRepository: context.read<RealtimeRepository>(),
        ),
        // dispose: обязателен — репозиторий держит StreamSubscription.
        dispose: (repo) => repo.dispose(),
      ),
    ],
    // BLoC на уровне scope — если нужен для нескольких страниц фичи.
    // Для одной страницы — BlocProvider в NavigationConfig.providers.
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
