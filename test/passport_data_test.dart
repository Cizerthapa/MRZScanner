import 'package:flutter_test/flutter_test.dart';
import 'package:mrzreader/model/passport_data.dart';

void main() {
  test('PassportData.toMap parses valid date correctly', () {
    final data = PassportData(
      documentType: 'P',
      issuingCountry: 'USA',
      surname: 'DOE',
      givenNames: 'JOHN',
      passportNumber: '123456789',
      nationality: 'USA',
      dateOfBirth: '800101', // Jan 1, 1980
      sex: 'M',
      expirationDate: '250101', // Jan 1, 2025
      personalNumber: 'P123456',
    );

    final map = data.toMap();
    expect(map['Date of Birth'], '01/01/1980');
    expect(map['Expiration Date'], '01/01/2025');
  });

  test('PassportData.toMap handles invalid date strings gracefully', () {
    // This test simulates the crash condition: 'K<'
    final data = PassportData(
      documentType: 'P',
      issuingCountry: 'USA',
      surname: 'DOE',
      givenNames: 'JOHN',
      passportNumber: '123456789',
      nationality: 'USA',
      dateOfBirth: 'K<0101', // Invalid format
      sex: 'M',
      expirationDate: '<<<<<<', // Invalid format
      personalNumber: 'P123456',
    );

    // Should not throw FormatException
    final map = data.toMap();

    // Expect original string or safe fallback, depending on implementation
    // For now, based on plan, we return the original string if parsing fails
    expect(map['Date of Birth'], 'K<0101');
    expect(map['Expiration Date'], '<<<<<<');
  });
}
