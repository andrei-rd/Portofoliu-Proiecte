import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PdfHelper {
  static Future<void> generateProfessionalInvoice({
    required Map<String, dynamic> data,
    bool isStorno = false,
  }) async {
    final pdf = pw.Document();

    // Data Extraction with safety
    final String invoiceNum = data['invoiceNumber'] ?? 'INV-UNKNOWN';
    final DateTime createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final String dateStr = DateFormat('dd.MM.yyyy').format(createdAt);
    
    final buyer = data['buyer'] as Map<String, dynamic>? ?? {};
    final items = (data['items'] as List?) ?? [];
    final totals = data['totals'] as Map<String, dynamic>? ?? {};

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER: BRANDING & TITLE
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 20,
                            height: 20,
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.blue800,
                              shape: pw.BoxShape.circle,
                            ),
                            child: pw.Center(child: pw.Text('P', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14))),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text('PARKLY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 22, color: PdfColors.blue800)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('PARKLY APP SRL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('Smart Urban Parking Solutions'),
                      pw.SizedBox(height: 8),
                      pw.Text('CIF: RO48291022'),
                      pw.Text('Reg. Com: J40/9921/2023'),
                      pw.Text('Bucuresti, Sector 1'),
                      pw.Text('Email: billing@parkly.ro'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(isStorno ? 'FACTURA STORNO' : 'FACTURA FISCALA', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24, color: isStorno ? PdfColors.red : PdfColors.black)),
                      pw.Text('Serie/Nr: $invoiceNum'),
                      pw.Text('Data Emiterii: $dateStr'),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                        child: pw.Text('ORIGINAL', style: const pw.TextStyle(fontSize: 8)),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 40),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 20),

              // CLIENT INFO
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(), // Spacer
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CUMPARATOR:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(buyer['name'] ?? 'Client Parkly', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text(buyer['email'] ?? 'Contact nespecificat'),
                      pw.Container(
                        width: 200,
                        child: pw.Text(buyer['address'] ?? 'Adresa de facturare lipsa', style: const pw.TextStyle(fontSize: 10)),
                      ),
                      if (buyer['cui'] != null) pw.Text('CIF/CUI: ${buyer['cui']}'),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 40),

              // TABLE OF ITEMS
              pw.Table.fromTextArray(
                border: null,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
                headers: ['Descriere Servicii Parcare', 'Cant.', 'Pret Unitar', 'TVA (20%)', 'Valoare Totala'],
                data: items.map((item) {
                  double val = (item['totalPrice'] as num? ?? 0).toDouble();
                  if (isStorno) val = -val;
                  return [
                    item['description'] ?? 'Rezervare loc parcare',
                    '1',
                    '${(item['unitPrice'] as num? ?? 0).toStringAsFixed(2)} RON',
                    '${(item['vatValue'] as num? ?? 0).toStringAsFixed(2)} RON',
                    '${val.toStringAsFixed(2)} RON',
                  ];
                }).toList(),
              ),

              // TOTALS SECTION
              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildTotalRow('Suma Neta (Fara TVA):', totals['totalNet'], false),
                      _buildTotalRow('TVA Total (20%):', totals['totalVat'], false),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        width: 200,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        child: _buildTotalRow('TOTAL DE PLATA:', totals['totalGross'], true),
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),
              
              // FOOTER
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Factura circula fara semnatura si stampila conform Codului Fiscal.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                  pw.Text('Pagina 1 / 1', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Factura_$invoiceNum.pdf',
    );
  }

  static pw.Widget _buildTotalRow(String label, dynamic value, bool isBold) {
    final double val = (value as num? ?? 0).toDouble();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: isBold ? 12 : 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.SizedBox(width: 20),
          pw.Text('${val.toStringAsFixed(2)} RON', style: pw.TextStyle(fontSize: isBold ? 12 : 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}
