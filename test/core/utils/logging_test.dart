import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

void main() {
  group('Logging', () {
    test('info 应不抛异常', () {
      expect(() => Logging.info('test info'), returnsNormally);
    });

    test('debug 应不抛异常', () {
      expect(() => Logging.debug('test debug'), returnsNormally);
    });

    test('warning 应不抛异常', () {
      expect(() => Logging.warning('test warning'), returnsNormally);
    });

    test('error 仅消息应不抛异常', () {
      expect(() => Logging.error('test error'), returnsNormally);
    });

    test('error 含 exception 应不抛异常', () {
      expect(
        () => Logging.error('test error', exception: Exception('test')),
        returnsNormally,
      );
    });

    test('error 含 exception + stackTrace 应不抛异常', () {
      expect(
        () => Logging.error(
          'test error',
          exception: Exception('test'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('空消息不抛异常', () {
      expect(() => Logging.info(''), returnsNormally);
      expect(() => Logging.debug(''), returnsNormally);
      expect(() => Logging.warning(''), returnsNormally);
      expect(() => Logging.error(''), returnsNormally);
    });

    test('中文消息不抛异常', () {
      expect(() => Logging.info('中文日志消息'), returnsNormally);
      expect(() => Logging.error('错误消息'), returnsNormally);
    });

    test('连续调用不抛异常', () {
      expect(() {
        Logging.info('info');
        Logging.debug('debug');
        Logging.warning('warning');
        Logging.error('error');
      }, returnsNormally);
    });
  });
}
