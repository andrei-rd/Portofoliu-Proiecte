import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'admin_service.dart';
import '../utils/pdf_helper.dart';

class FinancialHubScreen extends StatefulWidget {
  const FinancialHubScreen({super.key});

  @override
  State<FinancialHubScreen> createState() => _FinancialHubScreenState();
}

class _FinancialHubScreenState extends State<FinancialHubScreen> {
  String _statusFilter = 'toate';
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Financial Hub & Compliance', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildAnalyticsHeader(),
          _buildFilters(),
          Expanded(child: _buildInvoiceTable(adminService)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          _buildFinancialCard('Venit Brut (Total)', 'invoices', 'totals.totalGross', Colors.green, isCurrency: true, excludeStatus: 'stornat'),
          _buildPlatformProfitCard(),
          _buildFinancialCard('Circulating Supply', 'users', 'walletBalance', Colors.orange, isCurrency: true),
        ],
      ),
    );
  }

  Widget _buildPlatformProfitCard() {
    return Expanded(
      child: StreamBuilder<double>(
        stream: Provider.of<AdminService>(context, listen: false).totalPlatformProfitStream,
        builder: (context, snapshot) {
          double profit = snapshot.data ?? 0;
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Platform Profit', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Text(
                    NumberFormat.currency(symbol: 'RON').format(profit),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFinancialCard(String title, String collection, String fieldPath, Color color, {bool isCurrency = false, String? excludeStatus}) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(collection).snapshots(),
        builder: (context, snapshot) {
          double total = 0;
          if (snapshot.hasData && snapshot.data != null) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) continue;
              if (excludeStatus != null && data['paymentStatus'] == excludeStatus) continue;
              dynamic value;
              if (fieldPath.contains('.')) {
                final parts = fieldPath.split('.');
                value = data[parts[0]]?[parts[1]];
              } else {
                value = data[fieldPath];
              }
              total += (value ?? 0).toDouble();
            }
          }
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Text(
                    isCurrency ? NumberFormat.currency(symbol: 'RON').format(total) : total.toString(),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          DropdownButton<String>(
            value: _statusFilter,
            items: const [
              DropdownMenuItem(value: 'toate', child: Text('Toate Statusurile')),
              DropdownMenuItem(value: 'emis', child: Text('Emise')),
              DropdownMenuItem(value: 'stornat', child: Text('Stornate')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v!),
          ),
          const SizedBox(width: 24),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(_dateRange == null ? 'Filtrează după Dată' : '${DateFormat('dd.MM').format(_dateRange!.start)} - ${DateFormat('dd.MM').format(_dateRange!.end)}'),
            onPressed: () async {
              final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now());
              if (picked != null) setState(() => _dateRange = picked);
            },
          ),
          if (_dateRange != null) IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _dateRange = null)),
        ],
      ),
    );
  }

  Widget _buildInvoiceTable(AdminService service) {
    return StreamBuilder<QuerySnapshot>(
      stream: service.invoicesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data?.docs ?? [];
        
        // Sortează documentele: cele noi primele (descrescător)
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTs = (aData['createdAt'] ?? aData['issuedAt']) as Timestamp?;
          final bTs = (bData['createdAt'] ?? bData['issuedAt']) as Timestamp?;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        if (_statusFilter != 'toate') {
          docs = docs.where((d) {
            final dData = d.data() as Map<String, dynamic>;
            final dStatus = dData['paymentStatus'] ?? dData['status'] ?? 'emis';
            return dStatus == _statusFilter;
          }).toList();
        }
        if (_dateRange != null) {
          docs = docs.where((d) {
            final ts = (d.data() as Map)['createdAt'] as Timestamp?;
            if (ts == null) return false;
            final date = ts.toDate();
            return date.isAfter(_dateRange!.start) && date.isBefore(_dateRange!.end.add(const Duration(days: 1)));
          }).toList();
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _InvoiceRow(data: data, docId: doc.id, service: service);
          },
        );
      },
    );
  }
}

class _InvoiceRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final AdminService service;
  const _InvoiceRow({required this.data, required this.docId, required this.service});
  @override
  State<_InvoiceRow> createState() => _InvoiceRowState();
}

class _InvoiceRowState extends State<_InvoiceRow> {
  bool _isExpanded = false;
  @override
  Widget build(BuildContext context) {
    final status = widget.data['paymentStatus'] ?? widget.data['status'] ?? 'emis';
    final ts = (widget.data['createdAt'] ?? widget.data['issuedAt']) as Timestamp?;
    final dateStr = ts != null ? DateFormat('dd.MM.yyyy HH:mm').format(ts.toDate()) : 'Data N/A';
    final gross = (widget.data['totals']?['totalGross'] as num? ?? 0).toDouble();
    final buyer = widget.data['buyer'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            leading: CircleAvatar(
              backgroundColor: status == 'stornat' ? Colors.red.shade50 : Colors.green.shade50,
              child: Icon(status == 'stornat' ? Icons.remove_circle_outline : Icons.receipt_long_outlined, color: status == 'stornat' ? Colors.red : Colors.green, size: 20),
            ),
            title: Text(widget.data['invoiceNumber'] ?? 'INV-${widget.docId.substring(0, 5).toUpperCase()}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            subtitle: Text('${buyer['name'] ?? 'Client'} • $dateStr', style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${gross.toStringAsFixed(2)} RON', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 16),
                _buildStatusChip(status),
                Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              ],
            ),
          ),
        ),
        if (_isExpanded) _buildExpandedPreview(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.blue;
    if (status == 'stornat') color = Colors.red;
    if (status == 'emis' || status == 'achitat') color = Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildExpandedPreview() {
    final buyer = widget.data['buyer'] as Map<String, dynamic>? ?? {};
    final totals = widget.data['totals'] as Map<String, dynamic>? ?? {};
    final isStorno = widget.data['paymentStatus'] == 'stornat';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isStorno)
                TextButton.icon(onPressed: _confirmStorno, icon: const Icon(Icons.undo, color: Colors.red), label: const Text("STORNO", style: TextStyle(color: Colors.red))),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => PdfHelper.generateProfessionalInvoice(data: widget.data, isStorno: isStorno),
                icon: const Icon(Icons.download),
                label: const Text("DOWNLOAD PDF"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              ),
            ],
          ),
          const Divider(height: 48),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEntityBox("FURNIZOR", "PARKLY APP SRL", "CIF: RO48291022\nBucuresti, Sector 1\nEmail: billing@parkly.ro"),
              const Spacer(),
              _buildEntityBox("CUMPARATOR", buyer['name'] ?? 'Nespecificat', "${buyer['address'] ?? 'Adresa lipsa'}\n${buyer['email'] ?? ''}", canEdit: true, userId: widget.data['userId']),
            ],
          ),
          const SizedBox(height: 48),
          const Text("DETALII SERVICII", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          const Divider(),
          _buildItemsList(),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  _buildTotalRow("Suma Neta:", "${(totals['totalNet'] as num? ?? 0).toStringAsFixed(2)} RON"),
                  _buildTotalRow("TVA (20%):", "${(totals['totalVat'] as num? ?? 0).toStringAsFixed(2)} RON"),
                  const Divider(),
                  _buildTotalRow("TOTAL:", "${(totals['totalGross'] as num? ?? 0).toStringAsFixed(2)} RON", isBold: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityBox(String label, String name, String details, {bool canEdit = false, String? userId}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(width: 180, child: Text(details, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
            if (canEdit && userId != null) IconButton(icon: const Icon(Icons.edit_location_alt_outlined, size: 16, color: Colors.blue), onPressed: () => _editAddress(userId, details.split('\n')[0]))
          ],
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    final items = (widget.data['items'] as List?) ?? [];
    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(item['description'] ?? 'Servicii parcare', style: const TextStyle(fontWeight: FontWeight.w500))),
            Text("1 x ${(item['unitPrice'] as num? ?? 0).toStringAsFixed(2)} RON", style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  void _confirmStorno() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmare Stornare"),
        content: const Text("Aceasta actiune va invalida factura curenta si va emite un document de corecție."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anuleaza")),
          ElevatedButton(onPressed: () async { Navigator.pop(context); await widget.service.stornoInvoice(widget.docId); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Factura a fost stornata!"))); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("STORNO")),
        ],
      ),
    );
  }

  void _editAddress(String userId, String currentAddress) {
    final controller = TextEditingController(text: currentAddress);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Actualizare Date Facturare"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "Adresa noua")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anuleaza")),
          ElevatedButton(onPressed: () async { await widget.service.updateUserAddress(userId, controller.text); if (mounted) Navigator.pop(context); }, child: const Text("Salveaza")),
        ],
      ),
    );
  }
}
