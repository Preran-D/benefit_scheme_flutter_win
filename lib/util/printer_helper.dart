import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/model/payment.dart';

class PrinterHelper {
  static Future<void> printReceipt(Payment payment) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Thermal printer 80mm format
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('SHREE GAYATHRI', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Text('Benefit Scheme', style: const pw.TextStyle(fontSize: 18)),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('RECEIPT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Receipt No:'), pw.Text(payment.id.toString())]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Scheme ID:'), pw.Text(payment.schemeId.toString())]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Date:'), pw.Text(payment.paymentDate ?? 'Unknown')]),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('AMOUNT PAID:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rs. ${payment.amount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment Mode:'),
                  pw.Text(payment.paymentModes.map((e) => e.name).join(', ')),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Thank you!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_${payment.id}',
    );
  }
}
