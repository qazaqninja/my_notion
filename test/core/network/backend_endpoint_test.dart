import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/network/backend_endpoint.dart';

void main() {
  group('backend_endpoint (E57)', () {
    group('publicFormUrl', () {
      test('joins backendBaseUrl + /forms/<ulid>', () {
        expect(
          publicFormUrl(
            backendBaseUrl: 'http://localhost:8080',
            pageUlid: '01HX0V0000000000000000000A',
          ),
          'http://localhost:8080/forms/01HX0V0000000000000000000A',
        );
      });

      test('normalises a trailing slash on the base URL', () {
        expect(
          publicFormUrl(
            backendBaseUrl: 'http://localhost:8080/',
            pageUlid: '01HX0V0000000000000000000A',
          ),
          'http://localhost:8080/forms/01HX0V0000000000000000000A',
        );
      });

      test('works with https + custom port', () {
        expect(
          publicFormUrl(
            backendBaseUrl: 'https://quill.example.com:9443',
            pageUlid: '01HX0V0000000000000000000A',
          ),
          'https://quill.example.com:9443/forms/01HX0V0000000000000000000A',
        );
      });

      test('works with a path-suffixed base URL (e.g. behind a reverse proxy)',
          () {
        expect(
          publicFormUrl(
            backendBaseUrl: 'https://example.com/quill',
            pageUlid: '01HX0V0000000000000000000A',
          ),
          'https://example.com/quill/forms/01HX0V0000000000000000000A',
        );
      });
    });

    group('default endpoint constants', () {
      test('kBackendHttpBaseUrl + kBackendWsBaseUrl resolve to localhost:8080',
          () {
        // Both share the host:port the backend serves on today.
        // When E14+ settings expose an override, both constants will
        // read from the same stored value.
        expect(kBackendHttpBaseUrl, 'http://localhost:8080');
        expect(kBackendWsBaseUrl, 'ws://localhost:8080');
      });
    });
  });
}
