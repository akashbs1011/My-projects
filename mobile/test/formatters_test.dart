import 'package:clinical_ai/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('percent', () {
    test('converts the API 0-1 range to whole percentages', () {
      expect(Formatters.percent(0.82), '82%');
      expect(Formatters.percent(0.6667), '67%');
      expect(Formatters.percent(1.0), '100%');
      expect(Formatters.percent(0), '0%');
    });

    test('treats a null score as zero rather than crashing', () {
      expect(Formatters.percent(null), '0%');
    });
  });

  group('symptomLabel', () {
    test('capitalises lowercase dataset names', () {
      expect(Formatters.symptomLabel('high fever'), 'High fever');
      expect(Formatters.symptomLabel(''), '');
    });
  });

  group('date', () {
    test('renders a placeholder for a missing date', () {
      expect(Formatters.date(null), '—');
    });
  });
}
