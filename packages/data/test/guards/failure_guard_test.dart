import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guard', () {
    test('returns the action result on success', () async {
      final result = await guard(() async => 42);

      expect(result, 42);
    });

    test('wraps a plain exception using the default mapper', () async {
      Future<void> action() async => throw StateError('boom');

      await expectLater(guard(action), throwsA(isA<UnexpectedFailure>()));
    });

    test('uses the supplied mapper', () async {
      Future<void> action() async => throw StateError('boom');
      DomainFailure map(Object error) => NotFoundFailure(error);

      await expectLater(guard(action, mapper: map), throwsA(isA<NotFoundFailure>()));
    });

    test('rethrows an existing DomainFailure unchanged, without remapping', () async {
      const original = ValidationFailure('bad input');
      Future<void> action() async => throw original;
      var mapperCalls = 0;
      DomainFailure map(Object error) {
        mapperCalls++;
        return UnexpectedFailure(error);
      }

      await expectLater(guard(action, mapper: map), throwsA(same(original)));
      expect(mapperCalls, 0);
    });
  });

  group('guardStream', () {
    test('passes through emitted values', () {
      Stream<int> action() => Stream.fromIterable([1, 2, 3]);

      expect(guardStream(action), emitsInOrder([1, 2, 3, emitsDone]));
    });

    test('wraps a stream error using the default mapper', () {
      Stream<int> action() => Stream.error(StateError('boom'));

      expect(guardStream(action), emitsError(isA<UnexpectedFailure>()));
    });

    test('does not remap an existing DomainFailure emitted by the stream', () {
      const original = ConnectivityFailure('offline');
      Stream<int> action() => Stream.error(original);

      expect(guardStream(action), emitsError(same(original)));
    });
  });
}
