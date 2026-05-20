import 'package:flutter/cupertino.dart';

// ignore_for_file: avoid_print

/// Конфигурация фичи: константы и утилиты логирования.
///
/// Паттерн: один `abstract class` с приватным конструктором.
/// Все константы — static const, не нужен экземпляр.
abstract class ExampleConfig {
  ExampleConfig._();

  static const bool logs = true;
  static const int pageSize = 50;

  static void log(String message, {StackTrace? trace}) => logs
      ? (trace != null
            ? () {
                debugPrint(message);
                debugPrintStack(stackTrace: trace);
              }.call()
            : debugPrint(message))
      : null;
}
