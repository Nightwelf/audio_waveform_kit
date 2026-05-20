import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/doc/example/domain/model/example_item.dart';
import 'package:voice_message/doc/example/presentation/bloc/example_items/example_items_bloc.dart';

/// UI-страница фичи.
///
/// Паттерны:
/// - StatelessWidget + BlocBuilder (не StatefulWidget)
/// - context.read() только вне build (например, в onPressed/initState)
/// - buildWhen из State для контроля rebuild
/// - BlocBuilder/BlocListener разделены: Builder для UI, Listener для side effects
class ExampleItemsPage extends StatelessWidget {
  const ExampleItemsPage({required this.channelId, super.key});

  static const name = 'example_items';

  final String channelId;

  @override
  Widget build(BuildContext context) {
    // Инициируем загрузку при первом build — BLoC уже в дереве через scope/config.
    context.read<ExampleItemsBloc>().add(
          ExampleItemsEvent$Load(channelId: channelId),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      body: BlocBuilder<ExampleItemsBloc, ExampleItemsState>(
        // buildWhen из State исключает rebuild при несущественных изменениях.
        buildWhen: ExampleItemsState.buildWhen,
        builder: (context, state) => switch (state) {
          ExampleItemsState$Loading() => const Center(
              child: CircularProgressIndicator(),
            ),
          ExampleItemsState$Error(:final error) => Center(
              child: Text(error ?? 'Ошибка загрузки'),
            ),
          ExampleItemsState$Loaded() => _ItemsList(state: state),
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
          final metrics = notification.metrics;
          // context.read() — корректно вне build-метода (в callback).
          context.read<ExampleItemsBloc>().add(
                ExampleItemsEvent$ScrollMetricsChanged(
                  pixels: metrics.pixels,
                  maxScrollExtent: metrics.maxScrollExtent,
                ),
              );
        }
        return false;
      },
      child: ListView.builder(
        itemCount: state.displayItems.length + (state.paginationInFlight ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.displayItems.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return _ItemTile(item: state.displayItems[index]);
        },
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final ExampleItem item;

  @override
  Widget build(BuildContext context) => switch (item) {
        ExampleItem$Content(:final title, :final isDeleted) => ListTile(
            title: Text(isDeleted ? '[удалено]' : title),
          ),
        ExampleItem$System(:final text) => ListTile(
            title: Text(text),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
      };
}
