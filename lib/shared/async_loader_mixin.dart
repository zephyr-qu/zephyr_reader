import 'package:signals_flutter/signals_flutter.dart';

mixin AsyncLoaderMixin {
  Future<void> asyncLoad<T>(
    AsyncSignal<T> signal,
    Future<T> Function() fetcher,
  ) async {
    signal.value = AsyncState.loading();
    try {
      signal.value = AsyncState.data(await fetcher());
    } catch (e) {
      signal.value = AsyncState.error(e);
    }
  }
}
