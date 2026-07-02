import 'package:flutter_test/flutter_test.dart';
import 'package:ses_coin/common/date_utils.dart';

void main() {
  group('formatLoanDueDateLabel', () {
    test('formats due date with hour and minute', () {
      final dt = DateTime(2026, 7, 2, 14, 35);

      expect(formatLoanDueDateLabel(dt), '02/07/2026 14:35');
    });

    test('pads single-digit day, month, hour and minute', () {
      final dt = DateTime(2026, 7, 2, 5, 7);

      expect(formatLoanDueDateLabel(dt), '02/07/2026 05:07');
    });
  });
}
