import 'package:flutter_test/flutter_test.dart';
import 'package:gradtracker/models/user_model.dart';

void main() {
  test('academic year options retain a normalized out-of-range stored value',
      () {
    final options = academicYearOptions(
      firstStartYear: 2020,
      lastStartYear: 2025,
      include: ' 2018-2019 ',
    );

    expect(options, contains('2018\u20132019'));
  });

  test('academic year options do not duplicate an in-range stored value', () {
    final options = academicYearOptions(
      firstStartYear: 2020,
      lastStartYear: 2025,
      include: '2023-2024',
    );

    expect(options.where((option) => option == '2023\u20132024'), hasLength(1));
  });
}
