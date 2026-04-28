import 'package:clubline/core/stream_link_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'stream status labels use safe Italian labels for all supported states',
    () {
      expect(streamStatusLabel('live'), 'In diretta');
      expect(streamStatusLabel('scheduled'), 'Programmato');
      expect(streamStatusLabel('ended'), 'Conclusa');
      expect(streamStatusLabel('unknown'), 'Stato non verificato');
    },
  );

  test(
    'upcoming and unknown-like values normalize to safe persisted statuses',
    () {
      expect(normalizeStreamStatus('upcoming'), 'scheduled');
      expect(normalizeStreamStatus('offline'), 'unknown');
      expect(normalizeStreamStatus(null), 'unknown');
    },
  );
}
