import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'admin_service.dart';

class MonetizationDashboard extends StatefulWidget {
  final Function(int)? onNavigate;
  const MonetizationDashboard({super.key, this.onNavigate});

  @override
  State<MonetizationDashboard> createState() => _MonetizationDashboardState();
}

class _MonetizationDashboardState extends State<MonetizationDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFF2563EB);
    final adminService = Provider.of<AdminService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Parkly Monetization & Control', 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
            const SizedBox(width: 16),
            _buildLiveStatusBadge(),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          _buildProfitSummary(adminService),
          const VerticalDivider(color: Colors.white24, indent: 12, endIndent: 12, width: 24),
          _buildSyncButton(adminService),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Financial Performance", "Real-time revenue and liquidity monitoring"),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildMetricCard(
                        title: 'Gross Revenue',
                        stream: FirebaseFirestore.instance.collection('reservations').snapshots(),
                        icon: Icons.payments_outlined,
                        color: Colors.teal,
                        isCurrency: true,
                        filterStatus: 'completat',
                        trend: "+12.5%",
                      ),
                      _buildMetricCard(
                        title: 'Active Demand',
                        stream: FirebaseFirestore.instance.collection('reservations').snapshots(),
                        icon: Icons.speed_outlined,
                        color: brandColor,
                        filterStatus: 'activ',
                        trend: "Live",
                      ),
                      _buildMetricCard(
                        title: 'Total Liquidity',
                        stream: FirebaseFirestore.instance.collection('users').snapshots(),
                        icon: Icons.account_balance_wallet_outlined,
                        color: Colors.orange,
                        isCurrency: true,
                        sumField: 'walletBalance',
                        trend: "Global",
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  _buildSectionHeader("Management Hub", "Quick access to core administrative functions"),
                  const SizedBox(height: 24),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.6,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildEnhancedAction(context, 'Financial Hub', Icons.account_balance, 'Invoices & Taxes', 5, Colors.blue),
                      _buildEnhancedAction(context, 'Pricing Config', Icons.tune, 'Surge Multipliers', 6, Colors.indigo),
                      _buildEnhancedAction(context, 'Support Center', Icons.support_agent, 'User Disputes', 9, Colors.orange),
                      _buildEnhancedAction(context, 'Analytics Pro', Icons.analytics, 'Deep Data Insights', 10, Colors.purple),
                      _buildEnhancedAction(context, 'Audit Logs', Icons.security, 'Security Tracking', 11, Colors.blueGrey),
                      _buildEnhancedAction(context, 'Live Map', Icons.map_outlined, 'Spot Status', 1, Colors.teal),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Sidebar for Activity
          _buildActivitySidebar(adminService),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildLiveStatusBadge() {
    return FadeTransition(
      opacity: _pulseController,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            const Text("SYSTEM LIVE", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton(AdminService adminService) {
    return TextButton.icon(
      style: TextButton.styleFrom(backgroundColor: const Color(0xFF2563EB).withOpacity(0.1), padding: const EdgeInsets.symmetric(horizontal: 16)),
      icon: const Icon(Icons.sync, color: Colors.white, size: 18),
      label: const Text("Sync Data", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      onPressed: () async {
        showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
        final int synced = await adminService.syncMissingInvoices();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(synced > 0 ? 'Audit finalizat: $synced facturi noi generate.' : 'Toate datele sunt sincronizate.'),
            backgroundColor: synced > 0 ? Colors.green : Colors.blue,
          ));
        }
      },
    );
  }

  Widget _buildProfitSummary(AdminService adminService) {
    return StreamBuilder<Map<String, double>>(
      stream: adminService.detailedProfitStream,
      builder: (context, snapshot) {
        final data = snapshot.data ?? {'total': 0.0};
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text("TOTAL PLATFORM PROFIT", style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold)),
            Text("${data['total']?.toStringAsFixed(2)} RON", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace')),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required Stream<QuerySnapshot> stream,
    required IconData icon,
    required Color color,
    bool isCurrency = false,
    String? sumField,
    String? filterStatus,
    required String trend,
  }) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          double total = 0;
          int count = 0;
          if (snapshot.hasData) {
            final docs = filterStatus != null 
                ? snapshot.data!.docs.where((d) => (d.data() as Map)['status'] == filterStatus).toList()
                : snapshot.data!.docs;
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              total += (data[sumField ?? 'totalPrice'] ?? 0).toDouble();
            }
            count = docs.length;
          }
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(right: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(trend, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(isCurrency ? '${total.toStringAsFixed(2)} RON' : count.toString(), 
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'monospace')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedAction(BuildContext context, String title, IconData icon, String subtitle, int targetIndex, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        onTap: () => widget.onNavigate?.call(targetIndex),
        hoverColor: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivitySidebar(AdminService adminService) {
    return Container(
      width: 350,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: adminService.liveTransactionsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: LinearProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.separated(
                  itemCount: docs.length > 10 ? 10 : docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 24, endIndent: 24),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: data['status'] == 'activ' ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                        child: Icon(Icons.history, size: 18, color: data['status'] == 'activ' ? Colors.green : Colors.blue),
                      ),
                      title: Text(data['parkingName'] ?? 'New Reservation', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text("${data['carPlate'] ?? 'N/A'} • ${DateFormat('HH:mm').format(date)}", style: const TextStyle(fontSize: 11)),
                      trailing: Text("${data['totalPrice']} RON", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
