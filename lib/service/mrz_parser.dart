import 'dart:developer' as developer;

import 'package:mrzreader/model/passport_data.dart';

class MRZParser {
  static PassportData? parse(List<String> mrzLines) {
    developer.log('Parsing MRZ lines: $mrzLines', name: 'mrzreader.parser');
    try {
      if (mrzLines.length < 2) {
        developer.log(
          'Insufficient MRZ lines: ${mrzLines.length}',
          name: 'mrzreader.parser',
          level: 900,
        );
        return null;
      }

      String line1 = normalizeMRZLine(mrzLines[0], 44);
      String line2 = normalizeMRZLine(mrzLines[1], 44);

      // Validate MRZ format
      if (!_validateMRZ(line1, line2)) {
        developer.log(
          'MRZ validation failed for lines 1 and 2',
          name: 'mrzreader.parser',
          level: 900,
        );
        return null;
      }

      // Parse TD3 format (most common passport format - 2 lines of 44 characters)
      if (line1.length == 44 && line2.length == 44) {
        developer.log('Detected TD3 format', name: 'mrzreader.parser');
        return _parseTD3(line1, line2);
      }

      // Parse TD1 format (3 lines of 30 characters - ID cards)
      if (mrzLines.length >= 3 && line1.length == 30) {
        developer.log('Detected TD1 format', name: 'mrzreader.parser');
        return _parseTD1(mrzLines[0], mrzLines[1], mrzLines[2]);
      }

      developer.log(
        'Unknown MRZ format or line lengths: line1=${line1.length}, line2=${line2.length}',
        name: 'mrzreader.parser',
        level: 900,
      );
      return null;
    } catch (e, stackTrace) {
      developer.log(
        'Error parsing MRZ',
        error: e,
        stackTrace: stackTrace,
        name: 'mrzreader.parser',
        level: 1000,
      );
      return null;
    }
  }

  static bool _validateMRZ(String line1, String line2) {
    // Basic validation
    if (line1.isEmpty || line2.isEmpty) return false;

    // Should contain mostly valid MRZ characters
    RegExp validChars = RegExp(r'^[A-Z0-9<]+$');
    return validChars.hasMatch(line1) && validChars.hasMatch(line2);
  }

  static PassportData _parseTD3(String line1, String line2) {
    // Line 1
    String documentType = line1.startsWith('P')
        ? 'Passport'
        : line1.substring(0, 1);

    String issuingCountry = line1.substring(2, 5).replaceAll('<', '');

    String namesSection = line1.substring(5);
    List<String> nameParts = namesSection.split('<<');

    String surname = nameParts.isNotEmpty
        ? nameParts[0].replaceAll('<', ' ').trim()
        : '';

    String givenNames = nameParts.length > 1
        ? nameParts[1].replaceAll('<', ' ').trim()
        : '';

    // Line 2
    String passportNumber = line2.substring(0, 9).replaceAll('<', '').trim();

    String nationality = line2.substring(10, 13).replaceAll('<', '');

    String dateOfBirth = line2.substring(13, 19);
    String sex = line2.substring(20, 21);
    String expirationDate = line2.substring(21, 27);

    String personalNumber = line2.substring(28, 42).replaceAll('<', '').trim();

    return PassportData(
      documentType: documentType,
      issuingCountry: issuingCountry,
      surname: surname,
      givenNames: givenNames,
      passportNumber: passportNumber,
      nationality: nationality,
      dateOfBirth: dateOfBirth,
      sex: sex == 'M'
          ? 'Male'
          : sex == 'F'
          ? 'Female'
          : 'Unspecified',
      expirationDate: expirationDate,
      personalNumber: personalNumber,
    );
  }

  static String normalizeMRZLine(String line, int targetLength) {
    if (line.length > targetLength) {
      return line.substring(0, targetLength);
    }
    return line.padRight(targetLength, '<');
  }

  static PassportData _parseTD1(String line1, String line2, String line3) {
    // TD1 Format (ID cards):
    // Line 1: IISSUERPASSPORTNO<<<<<CHECKDIGIT
    // Line 2: DOB<SEX<EXPDATE<NATIONALITY<<<<<<<<CHECKDIGITS
    // Line 3: SURNAME<<GIVENNAMES<<<<<<<<<<<<<<<

    String documentType = line1.substring(0, 1);
    String issuingCountry = line1.length >= 5
        ? line1.substring(2, 5).replaceAll('<', '')
        : '';
    String passportNumber = line1.length >= 15
        ? _extractUntilCheck(line1, 5, 14)
        : '';

    String dateOfBirth = line2.length >= 6 ? line2.substring(0, 6) : '';
    String sex = line2.length >= 8 ? line2.substring(7, 8) : '';
    String expirationDate = line2.length >= 14 ? line2.substring(8, 14) : '';
    String nationality = line2.length >= 18
        ? line2.substring(15, 18).replaceAll('<', '')
        : '';

    String namesSection = line3;
    List<String> nameParts = namesSection.split('<<');
    String surname = nameParts.length > 0
        ? nameParts[0].replaceAll('<', ' ').trim()
        : '';
    String givenNames = nameParts.length > 1
        ? nameParts[1].replaceAll('<', ' ').trim()
        : '';

    return PassportData(
      documentType: documentType == 'I' ? 'ID Card' : documentType,
      issuingCountry: issuingCountry,
      surname: surname,
      givenNames: givenNames,
      passportNumber: passportNumber,
      nationality: nationality,
      dateOfBirth: dateOfBirth,
      sex: sex == 'M' ? 'Male' : (sex == 'F' ? 'Female' : sex),
      expirationDate: expirationDate,
      personalNumber: '',
    );
  }

  static String _extractUntilCheck(String line, int start, int end) {
    if (line.length <= end) {
      developer.log(
        'Extraction range out of bounds: line.length=${line.length}, end=$end',
        name: 'mrzreader.parser',
        level: 900,
      );
      String section = line.substring(start);
      return section.replaceAll('<', '').trim();
    }
    String section = line.substring(start, end + 1);
    return section.replaceAll('<', '').trim();
  }

  // ignore: unused_element
  static bool _verifyCheckDigit(String data, String checkDigit) {
    if (checkDigit == '<') return true; // Optional field

    int calculated = _calculateCheckDigit(data);
    return calculated == int.tryParse(checkDigit);
  }

  static int _calculateCheckDigit(String input) {
    const weights = [7, 3, 1];
    int sum = 0;

    for (int i = 0; i < input.length; i++) {
      String char = input[i];
      int value;

      if (char == '<') {
        value = 0;
      } else if (RegExp(r'[0-9]').hasMatch(char)) {
        value = int.parse(char);
      } else {
        value = char.codeUnitAt(0) - 'A'.codeUnitAt(0) + 10;
      }

      sum += value * weights[i % 3];
    }

    return sum % 10;
  }
}
