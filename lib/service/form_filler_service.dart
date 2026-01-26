import 'package:mrzreader/model/passport_data.dart';

class FormFillerService {
  static String fillForm(String htmlTemplate, PassportData data) {
    String filledHtml = htmlTemplate;

    // 1. Name boxes
    String fullName = '${data.surname} ${data.givenNames}'.toUpperCase().trim();
    filledHtml = filledHtml.replaceAll(
      '{{ name_boxes }}',
      _generateCharBoxes(fullName, 11),
    );

    // 2. Country boxes
    filledHtml = filledHtml.replaceAll(
      '{{ country_boxes }}',
      _generateCharBoxes(data.issuingCountry, 16),
    );

    // 3. Passport boxes
    filledHtml = filledHtml.replaceAll(
      '{{ passport_boxes }}',
      _generateCharBoxes(data.passportNumber, 11),
    );

    // 4. Visa boxes (not provided by MRZ, leave empty)
    filledHtml = filledHtml.replaceAll(
      '{{ visa_boxes }}',
      _generateCharBoxes('', 20),
    );

    // 5. Address boxes (not provided by MRZ, leave empty)
    filledHtml = filledHtml.replaceAll(
      '{{ address_boxes }}',
      _generateCharBoxes('', 20),
    );

    // 6. Dates
    // Assuming format is DD/MM/YYYY from PassportData.toMap() or direct from data
    // Let's use current date for the form submission date
    DateTime now = DateTime.now();
    filledHtml = filledHtml.replaceAll('{{ date_y }}', now.year.toString());
    filledHtml = filledHtml.replaceAll(
      '{{ date_m }}',
      now.month.toString().padLeft(2, '0'),
    );
    filledHtml = filledHtml.replaceAll(
      '{{ date_d }}',
      now.day.toString().padLeft(2, '0'),
    );

    return filledHtml;
  }

  static String _generateCharBoxes(String value, int totalBoxes) {
    StringBuffer sb = StringBuffer();
    List<String> chars = value.split('');

    for (int i = 0; i < totalBoxes; i++) {
      String char = i < chars.length ? chars[i] : '';
      sb.write('<div class="input-box">$char</div>\n');
    }

    return sb.toString();
  }
}
