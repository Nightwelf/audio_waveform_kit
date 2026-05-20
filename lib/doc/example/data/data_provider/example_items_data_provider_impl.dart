import 'package:voice_message/api_http_client/api_http_client.dart';
import 'package:voice_message/app_rtu/core/data/model/response.dart';
import 'package:voice_message/app_rtu/core/domain/model/user_id.dart';
import 'package:voice_message/doc/example/domain/data_provider/example_items_data_provider.dart';
import 'package:voice_message/doc/example/domain/model/example_item.dart';

/// HTTP-реализация DataProvider.
///
/// Паттерн:
/// - принимает ApiHttpClient, кастует к ApiHttpClientRtu для publicApiDio
/// - парсинг JSON через switch по type-полю → sealed variants
/// - все ошибки оборачиваются в AppResponse$Error, не бросаются выше
class ExampleItemsDataProviderImpl implements ExampleItemsDataProvider {
  ExampleItemsDataProviderImpl({required ApiHttpClient httpClient}) : _httpClient = httpClient as ApiHttpClientRtu;

  final ApiHttpClientRtu _httpClient;

  @override
  Future<AppResponse<ExampleItemsPage>> fetchItems({
    required String channelId,
    String? afterId,
    int? count,
  }) async {
    try {
      final response = await _httpClient.publicApiDio.get<Map<String, dynamic>>(
        '/channels/$channelId/items',
        queryParameters: {
          if (afterId != null) 'afterId': afterId,
          if (count != null) 'count': count,
        },
      );
      final data = response.data ?? {};
      final items = (data['items'] as List).cast<Map<String, dynamic>>().map(_parseItem).toList();
      final hasMore = data['hasMore'] as bool? ?? false;
      return AppResponse$Success(data: ExampleItemsPage(items: items, hasMore: hasMore));
    } catch (e) {
      return AppResponse$Error(error: ResponseError.unknown());
    }
  }

  @override
  Future<AppResponse<ExampleItem>> fetchItem({
    required String channelId,
    required String itemId,
  }) async {
    try {
      final response = await _httpClient.publicApiDio.get<Map<String, dynamic>>(
        '/channels/$channelId/items/$itemId',
      );
      return AppResponse$Success(data: _parseItem(response.data ?? {}));
    } catch (e) {
      return AppResponse$Error(error: ResponseError.unknown());
    }
  }

  /// Парсинг JSON через switch по type — exhaustive mapping на sealed variants.
  ExampleItem _parseItem(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'content' => ExampleItem$Content(
          id: json['id'] as String,
          authorId: UserGUID.fromApi(json['authorId'] as String),
          createdAt: DateTime.parse(json['createdAt'] as String),
          title: json['title'] as String,
          deletedBy: json['deletedBy'] as String?,
        ),
      'system' => ExampleItem$System(
          id: json['id'] as String,
          authorId: UserGUID.fromApi(json['authorId'] as String),
          createdAt: DateTime.parse(json['createdAt'] as String),
          text: json['text'] as String,
        ),
      _ => throw FormatException('Unknown item type: $type'),
    };
  }
}
