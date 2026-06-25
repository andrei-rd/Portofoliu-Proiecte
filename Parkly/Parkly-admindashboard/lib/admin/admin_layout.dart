import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_service.dart';
import 'monetization_dashboard.dart';
import 'live_transactions_screen.dart';
import 'availability_monitor_screen.dart';
import 'financial_hub_screen.dart';
import 'pricing_config_screen.dart';
import 'manage_users_screen.dart';
import 'support_tickets_screen.dart';
import 'analytics_screen.dart';
import 'system_logs_screen.dart';
import 'broadcast_screen.dart';
import 'live_map_screen.dart';
import 'manage_spots_screen.dart';
import 'notification_inbox_screen.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      MonetizationDashboard(onNavigate: (index) => setState(() => _selectedIndex = index)),
      const LiveMapScreen(),
      const ManageSpotsScreen(),
      const LiveTransactionsScreen(),
      const AvailabilityMonitorScreen(),
      const FinancialHubScreen(),
      const PricingConfigScreen(),
      const ManageUsersScreen(),
      const SupportTicketsScreen(),
      const AnalyticsScreen(),
      const SystemLogsScreen(),
      const BroadcastScreen(),
      const NotificationInboxScreen(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFF2563EB);
    final adminService = Provider.of<AdminService>(context, listen: false);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            extended: MediaQuery.of(context).size.width > 1200,
            onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
            backgroundColor: const Color(0xFF0F172A),
            unselectedIconTheme: const IconThemeData(color: Colors.white60),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white60, fontSize: 12),
            selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            indicatorColor: brandColor,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Icon(Icons.local_parking, size: 32, color: Colors.blueAccent),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: Text('Live Map')),
              NavigationRailDestination(icon: Icon(Icons.business_outlined), selectedIcon: Icon(Icons.business), label: Text('Assets')),
              NavigationRailDestination(icon: Icon(Icons.receipt_outlined), selectedIcon: Icon(Icons.receipt), label: Text('Transactions')),
              NavigationRailDestination(icon: Icon(Icons.view_timeline_outlined), selectedIcon: Icon(Icons.view_timeline), label: Text('Timeline')),
              NavigationRailDestination(icon: Icon(Icons.account_balance_outlined), selectedIcon: Icon(Icons.account_balance), label: Text('Finance')),
              NavigationRailDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: Text('Pricing')),
              NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Users')),
              NavigationRailDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: Text('Support')),
              NavigationRailDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: Text('Analytics')),
              NavigationRailDestination(icon: Icon(Icons.security_outlined), selectedIcon: Icon(Icons.security), label: Text('Audit Logs')),
              NavigationRailDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: Text('Broadcast')),
              NavigationRailDestination(icon: Icon(Icons.mail_outline), selectedIcon: Icon(Icons.mail), label: Text('Inbox Monitor')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white12),
          Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: _screens[_selectedIndex])),
        ],
      ),
    );
  }
}
