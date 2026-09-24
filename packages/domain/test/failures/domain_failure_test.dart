import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('DomainFailure', () {
    test('exposes the original cause', () {
      const failure = UnexpectedFailure('boom');

      expect(failure.cause, 'boom');
    });

    test('each subtype implements Exception', () {
      expect(const UnexpectedFailure('x'), isA<Exception>());
      expect(const NotFoundFailure('x'), isA<Exception>());
      expect(const ValidationFailure('x'), isA<Exception>());
      expect(const ConnectivityFailure('x'), isA<Exception>());
      expect(const UnauthorizedFailure('x'), isA<Exception>());
    });

    test('toString includes the runtime type and cause', () {
      expect(const NotFoundFailure('task-1').toString(), 'NotFoundFailure(cause: task-1)');
    });

    test('a switch over DomainFailure can be exhaustive', () {
      String describe(DomainFailure failure) => switch (failure) {
        UnexpectedFailure() => 'unexpected',
        NotFoundFailure() => 'not_found',
        ValidationFailure() => 'validation',
        ConnectivityFailure() => 'connectivity',
        UnauthorizedFailure() => 'unauthorized',
      };

      expect(describe(const NotFoundFailure('x')), 'not_found');
    });
  });
}
