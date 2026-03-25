import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 2));

/// Global observer that logs provider errors (AsyncError states).
base class AppProviderObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (newValue is AsyncError) {
      _log.w(
        '[ProviderObserver] ${context.provider.name ?? context.provider.runtimeType} → AsyncError',
        error: newValue.error,
        stackTrace: newValue.stackTrace,
      );
    }
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    _log.e(
      '[ProviderObserver] ${context.provider.name ?? context.provider.runtimeType} failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
