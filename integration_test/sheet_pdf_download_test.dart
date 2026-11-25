import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app/services/sheet_pdf_actions.dart';
import 'package:mobile_app/services/sheet_pdf_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saves a generated Bengali stock PDF to Android Downloads', (
    tester,
  ) async {
    final pdfService = SheetPdfService();
    final bytes = await pdfService.createStockPdf(
      company: {'name': 'PDF download test', 'address': 'ফেনী'},
      monthName: 'মে',
      year: 2026,
      selectedDate: DateTime(2026, 5, 2),
      range: PdfReportRange.monthly,
      rows: [
        {
          'date': '2026-05-02',
          'name': 'চাল',
          'stock': 2,
          'price': 10,
          'total': 20,
        },
      ],
    );
    final result = await savePdfToDownloads(
      name: 'bms_pdf_download_integration_test',
      bytes: bytes,
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(result, isNotNull);
    expect(result, isNotEmpty);
    // Used by the Android test runner to remove this named Downloads test file.
    // ignore: avoid_print
    print('PDF_DOWNLOAD_TEST_RESULT=$result');
  });
}
