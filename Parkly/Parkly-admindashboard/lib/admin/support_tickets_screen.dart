import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_service.dart';
import 'support_chat_screen.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  int _tabIndex = 0; // 0 for Standard Tickets, 1 for Occupancy Reports

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Centru Suport & Ticketing', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Row(
            children: [
              _buildTabButton(0, 'Tichete Standard', Icons.support_agent),
              StreamBuilder<QuerySnapshot>(
                stream: adminService.reportedOccupiedStream,
                builder: (context, snapshot) {
                  final int count = snapshot.data?.docs.length ?? 0;
                  return _buildTabButton(1, 'Raportări Loc Ocupat', Icons.report_problem, isAlert: count > 0, alertCount: count);
                }
              ),
            ],
          ),
        ),
      ),
      body: _tabIndex == 0 ? _buildStandardTickets(adminService) : _buildOccupancyReports(adminService),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon, {bool isAlert = false, int alertCount = 0}) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isSelected ? const Color(0xFF2563EB) : Colors.transparent, width: 3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF2563EB) : Colors.grey, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF2563EB) : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isAlert) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Center(
                    child: Text(
                      alertCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandardTickets(AdminService adminService) {
    return StreamBuilder<QuerySnapshot>(
      stream: adminService.ticketsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final tickets = snapshot.data!.docs;

        if (tickets.isEmpty) {
          return _buildEmptyState('Toate tichetele sunt rezolvate!', Icons.mark_chat_read_outlined, Colors.green);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            final data = ticket.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'open';
            final date = (data['updatedAt'] as Timestamp?)?.toDate();

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: CircleAvatar(
                  backgroundColor: status == 'open' ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  child: Icon(status == 'open' ? Icons.mail : Icons.done_all, color: status == 'open' ? Colors.orange : Colors.green),
                ),
                title: Text(data['subject'] ?? 'Problemă Tehnică', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['userName'] ?? data['userEmail'] ?? 'User anonim'),
                    if (date != null) Text(DateFormat('dd MMM, HH:mm').format(date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupportChatScreen(ticketId: ticket.id, ticketData: data),
                    ),
                  ),
                  child: Text(status == 'open' ? 'Răspunde' : 'Vezi Chat'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOccupancyReports(AdminService adminService) {
    return StreamBuilder<QuerySnapshot>(
      stream: adminService.reportedOccupiedStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final reports = snapshot.data!.docs;

        if (reports.isEmpty) {
          return _buildEmptyState('Nicio raportare de loc ocupat activă.', Icons.verified_user_outlined, Colors.blue);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: reports.length + 1, // +1 for the protocol card
          itemBuilder: (context, index) {
            if (index == 0) return _buildProtocolGuideCard();
            
            final report = reports[index - 1];
            final data = report.data() as Map<String, dynamic>;
            final reportedAt = (data['reportedAt'] ?? data['createdAt']) as Timestamp?;
            final dateStr = reportedAt != null ? DateFormat('dd MMM, HH:mm').format(reportedAt.toDate()) : 'Data N/A';
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade100)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Loc ocupat abuziv - ${data['parkingName'] ?? 'Parcare'}", 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                              const SizedBox(height: 4),
                              Text("${data['userEmail'] ?? data['userId'] ?? 'Utilizator'} • Mașină: ${data['carPlate'] ?? 'N/A'}",
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ],
                          ),
                        ),
                        _buildStatusChip('REPORTED'),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Raportat la: $dateStr", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Row(
                          children: [
                            if (data['evidenceUrl'] != null)
                              TextButton.icon(
                                icon: const Icon(Icons.image_outlined, size: 18),
                                label: const Text("Vezi Dovadă"),
                                onPressed: () => _showEvidence(context, data['evidenceUrl']),
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                              onPressed: () => _resolveIncident(context, report.id, data),
                              child: const Text("Rezolvă"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEvidence(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text("Dovadă Foto Loc Ocupat"), 
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () => launchUrl(Uri.parse(url)),
                    tooltip: "Deschide în Browser",
                  )
                ],
              ),
              Flexible(
                child: Image.network(
                  url, 
                  fit: BoxFit.contain, 
                  errorBuilder: (c, e, s) => Padding(
                    padding: const EdgeInsets.all(48.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          "Imaginea nu poate fi încărcată direct din cauza restricțiilor de securitate (CORS).",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => launchUrl(Uri.parse(url)),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text("Vezi imaginea în tab nou"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("Închide")
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resolveIncident(BuildContext context, String reservationId, Map<String, dynamic> data) {
    final adminService = Provider.of<AdminService>(context, listen: false);
    final ownerId = data['ownerId'] ?? 'N/A';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Decizie Garanție de Sistem"),
        content: Container(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProtocolInfo(),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                Text("DETALII INCIDENT:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade900)),
                const SizedBox(height: 8),
                Text("• Chiriaș: ${data['userEmail'] ?? 'N/A'}"),
                Text("• Proprietar: $ownerId"),
                Text("• Garanție de returnat: 2.00 RON"),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade200)),
                  child: const Text(
                    "Utilizatorul a primit deja refund-ul pentru parcare. Aprobarea aici returnează taxa de procesare (2 RON).",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ÎNCHIDE")
          ),
          TextButton(
            onPressed: () async {
              await adminService.rejectOccupancyReport(reservationId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Raportare respinsă. Garanția de 2 RON rămâne la platformă.")));
              }
            }, 
            child: const Text("RESPINGE RAPORT", style: TextStyle(color: Colors.red))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              await adminService.approveOccupancyRefund(reservationId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Refund Garanție (2 RON) procesat cu succes.")));
              }
            },
            child: const Text("APROBĂ REFUND GARANȚIE"),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.gavel, color: Colors.blue.shade800, size: 20),
            const SizedBox(width: 8),
            Text("PROTOCOL: Garanția de Sistem", 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        const Text("Misiune: Clientul a raportat locul ocupat. El a primit deja banii pe parcare înapoi, dar cei 2 RON sunt blocați la noi ca Garanție.", 
          style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black54)),
        const SizedBox(height: 12),
        _buildProtocolStep("1. Aprobă", 
          "Dacă poza confirmă ocuparea. Clientul primește cei 2 RON. Tranzacția se va numi: 'Refund Garanție Sistem'."),
        _buildProtocolStep("2. Respinge", 
          "Dacă poza e neclară. Cei 2 RON rămân la Parkly."),
      ],
    );
  }

  Widget _buildProtocolStep(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          Text(description, style: const TextStyle(fontSize: 10, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.shade200)),
      child: Text(label, style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildProtocolGuideCard() {
    return Card(
      color: Colors.blue.shade50,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 12),
                const Text("PROTOCOL: Garanția de Sistem", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
              ],
            ),
            const SizedBox(height: 8),
            const Text("Misiune: Clientul a raportat locul ocupat. El a primit deja banii pe parcare înapoi, dar cei 2 RON sunt blocați ca Garanție.",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1E3A8A))),
            const SizedBox(height: 12),
            const Text("1. Aprobă: Dacă poza confirmă ocuparea. Clientul primește cei 2 RON. (Refund Garanție Sistem).",
              style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF))),
            const Text("2. Respinge: Dacă poza e neclară. Cei 2 RON rămân la Parkly.",
              style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF))),
          ],
        ),
      ),
    );
  }
}
