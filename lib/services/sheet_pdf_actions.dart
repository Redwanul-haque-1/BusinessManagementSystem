import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'sheet_pdf_service.dart';

Future<PdfReportRange?> choosePdfReportRange(BuildContext context) {
  return showModalBottomSheet<PdfReportRange>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'হিসাবের সময় নির্বাচন করুন',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.today_outlined),
            title: const Text('দৈনিক হিসাব'),
            onTap: () => Navigator.pop(sheetContext, PdfReportRange.daily),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('মাসিক হিসাব'),
            onTap: () => Navigator.pop(sheetContext, PdfReportRange.monthly),
          ),
        ],
      ),
    ),
  );
}

Future<String?> savePdfToDownloads({
  required String name,
  required Uint8List bytes,
}) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return FileSaver.instance.saveAs(
      name: name,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
      dialogTitle: 'PDF সংরক্ষণ করুন',
    );
  }

  return FileSaver.instance.saveToDownloads(
    name: name,
    bytes: bytes,
    fileExtension: 'pdf',
    mimeType: MimeType.pdf,
  );
}

Future<void> sharePdf({
  required String name,
  required Uint8List bytes,
}) {
  return Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
}
