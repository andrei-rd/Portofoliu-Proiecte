import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvoicePdfService {
  static Future<void> generateAndDownload(
      Map<String, dynamic> invoiceData) async {
    final pdf = pw.Document();

    final buyer = (invoiceData['buyer'] as Map?)?.cast<String, dynamic>() ?? {};
    final seller = (invoiceData['seller'] as Map?)?.cast<String, dynamic>() ?? {};
    final totals = (invoiceData['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final items = (invoiceData['items'] as List?) ?? [];
    
    DateTime issuedAt;
    if (invoiceData['issuedAt'] is Timestamp) {
      issuedAt = (invoiceData['issuedAt'] as Timestamp).toDate();
    } else if (invoiceData['issuedAt'] is DateTime) {
      issuedAt = invoiceData['issuedAt'];
    } else {
      issuedAt = DateTime.now();
    }

    // Determine TVA rate from data or default to 20%
    final String vatRateStr = totals['vatRate']?.toString() ?? '20%';
    final double vatMultiplier = vatRateStr.contains('19') ? 0.19 : 0.20;

    final logo = await imageFromAssetBundle('lib/assets/logo.png');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PARKLY APP SRL',
                          style: pw.TextStyle(
                              color: PdfColor.fromHex('#2563EB'),
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text('Smart Urban Parking Solutions',
                          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey900)),
                      pw.SizedBox(height: 10),
                      pw.Text('CIF: ${seller['cif'] ?? 'RO48291022'}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Reg. Com: ${seller['regCom'] ?? 'J40/9921/2023'}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(seller['address'] ?? 'Bucuresti, Sector 1', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Email: ${seller['email'] ?? 'billing@parkly.ro'}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Image(logo, width: 70, height: 70),
                      pw.SizedBox(height: 5),
                      pw.Text('FACTURA FISCALA',
                          style: pw.TextStyle(
                              fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Serie/Nr: ${invoiceData['invoiceNumber']}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Data Emiterii: ${DateFormat('dd.MM.yyyy').format(issuedAt)}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Ora: ${DateFormat('HH:mm:ss').format(issuedAt)}', style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400)),
                        child: pw.Text('ORIGINAL',
                            style: const pw.TextStyle(fontSize: 8)),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 40),

              // Buyer Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Provider Section (Owner)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PRESTATOR SERVICIU:',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(invoiceData['provider']?['name'] ?? 'N/A',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text(invoiceData['provider']?['email'] ?? '', style: const pw.TextStyle(fontSize: 9)),
                      if (invoiceData['provider']?['phone'] != null && invoiceData['provider']?['phone'] != 'Nespecificat')
                        pw.Text('Tel: ${invoiceData['provider']?['phone']}', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 4),
                      pw.Text('Locatia: ${invoiceData['provider']?['parkingName'] ?? 'N/A'}',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Loc Parcare: ${invoiceData['provider']?['spotNumber'] ?? 'N/A'}',
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  // Buyer Section
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CUMPARATOR:',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(buyer['name'] ?? 'N/A',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                        pw.Text(buyer['email'] ?? '', style: const pw.TextStyle(fontSize: 10)),
                        if (buyer['phone'] != null && buyer['phone'] != 'Nespecificat')
                          pw.Text('Tel: ${buyer['phone']}', style: const pw.TextStyle(fontSize: 10)),
                        if (buyer['address'] != null && buyer['address'].toString().isNotEmpty && buyer['address'] != 'Nespecificată')
                          pw.Text(buyer['address'], style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 50),

              // Table
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(
                    color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                headerDecoration:
                    pw.BoxDecoration(color: PdfColor.fromHex('#2563EB')),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 9),
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                },
                data: <List<String>>[
                  <String>[
                    'Descriere Servicii',
                    'Cant.',
                    'Pret Unitar',
                    'TVA ($vatRateStr)',
                    'Valoare Totala'
                  ],
                  ...items.map((itemData) {
                    final item = (itemData as Map?)?.cast<String, dynamic>() ?? {};
                    final unitPrice = (item['unitPrice'] ?? 0.0).toDouble();
                    final quantity = (item['quantity'] ?? 1).toInt();
                    final totalNet = (item['totalNet'] ?? (unitPrice * quantity)).toDouble();
                    
                    final double vat = totalNet * vatMultiplier;
                    final double totalGross = totalNet + vat;
                    
                    return [
                      item['description']?.toString() ?? 'Servicii parcare',
                      quantity.toString(),
                      '${unitPrice.toStringAsFixed(2)} RON',
                      '${vat.toStringAsFixed(2)} RON',
                      '${totalGross.toStringAsFixed(2)} RON',
                    ];
                  }),
                ],
              ),

              pw.SizedBox(height: 30),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 10),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Row(
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Text('Suma Neta (Fara TVA): ', style: const pw.TextStyle(fontSize: 9)),
                                pw.SizedBox(width: 30),
                                pw.Text('${(totals['totalNet'] ?? totals['netTotal'] ?? 0.0).toDouble().toStringAsFixed(2)} RON', style: const pw.TextStyle(fontSize: 9)),
                              ],
                            ),
                            pw.SizedBox(height: 4),
                            pw.Row(
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Text('TVA Total ($vatRateStr): ', style: const pw.TextStyle(fontSize: 9)),
                                pw.SizedBox(width: 30),
                                pw.Text('${(totals['totalVat'] ?? totals['vatAmount'] ?? 0.0).toDouble().toStringAsFixed(2)} RON', style: const pw.TextStyle(fontSize: 9)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 15),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 15, vertical: 10),
                        decoration: const pw.BoxDecoration(
                            color: PdfColors.grey100),
                        child: pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text('TOTAL DE PLATA: ',
                                style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(width: 25),
                            pw.Text('${(totals['totalGross'] ?? totals['grossTotal'] ?? 0.0).toDouble().toStringAsFixed(2)} RON',
                                style: pw.TextStyle(
                                    fontSize: 13,
                                    fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                    'Generat automat de Parkly Systems. Va multumim ca folositi serviciile noastre!',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey)),
              ),
            ],
          );
        },
      ),
    );

    // Deschide dialogul nativ de salvare/printare
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Factura_${invoiceData['invoiceNumber']}.pdf',
    );
  }
}
