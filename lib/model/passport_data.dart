class PassportData {
  final String documentType;
  final String issuingCountry;
  final String surname;
  final String givenNames;
  final String passportNumber;
  final String nationality;
  final String dateOfBirth;
  final String sex;
  final String expirationDate;
  final String personalNumber;

  PassportData({
    required this.documentType,
    required this.issuingCountry,
    required this.surname,
    required this.givenNames,
    required this.passportNumber,
    required this.nationality,
    required this.dateOfBirth,
    required this.sex,
    required this.expirationDate,
    required this.personalNumber,
  });

  Map<String, String> toMap() {
    return {
      'Document Type': documentType,
      'Issuing Country': issuingCountry,
      'Surname': surname,
      'Given Names': givenNames,
      'Passport Number': passportNumber,
      'Nationality': nationality,
      'Date of Birth': _formatDate(dateOfBirth),
      'Sex': sex,
      'Expiration Date': _formatDate(expirationDate),
      'Personal Number': personalNumber,
    };
  }

  String _formatDate(String date) {
    if (date.length == 6) {
      if (!RegExp(r'^\d{6}$').hasMatch(date)) {
        return date;
      }
      String year = date.substring(0, 2);
      String month = date.substring(2, 4);
      String day = date.substring(4, 6);

      // Assume years 00-30 are 2000s, 31-99 are 1900s
      int? yearInt = int.tryParse(year);
      if (yearInt == null) return date;

      String fullYear = yearInt <= 30 ? '20$year' : '19$year';

      return '$day/$month/$fullYear';
    }
    return date;
  }
}
