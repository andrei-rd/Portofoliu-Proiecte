import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'admin_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context, listen: false);
    const Color brandColor = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Intelligent Analytics Dashboard', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white, size: 20),
            onPressed: () {},
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: adminService.heatmapAnalyticsStream,
        builder: (context, snapshot) {
          int activeReservations = snapshot.data?.docs.length ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP HEADER & KPI ROW
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Business Overview", 
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        Text("Last updated: Just now", 
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                    _buildLivePulseBadge(activeReservations),
                  ],
                ),
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    _buildKpiCard("Total Revenue", "42,850 RON", Icons.payments, Colors.green, "+12.5%"),
                    _buildKpiCard("Avg. Duration", "2h 45m", Icons.timer, Colors.orange, "-2.1%"),
                    _buildKpiCard("Active Users", "1,204", Icons.people, brandColor, "+5.4%"),
                    _buildKpiCard("Util. Rate", "78%", Icons.pie_chart, Colors.purple, "+3.0%"),
                  ],
                ),
                const SizedBox(height: 32),

                // 2. MAIN TREND CHART
                _buildChartCard(
                  title: "Revenue Trend (Last 7 Days)",
                  subtitle: "Visualizing daily growth and peak earnings periods",
                  chart: _buildLineChart(),
                ),
                const SizedBox(height: 32),

                // 3. BOTTOM ROW CHARTS
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildChartCard(
                        title: "Payment Methods",
                        subtitle: "User preference breakdown",
                        chart: _buildPieChart(),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 2,
                      child: _buildChartCard(
                        title: "Weekly Peak Occupancy",
                        subtitle: "Comparison of high-demand days",
                        chart: _buildBarChart(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildLivePulseBadge(int count) {
    Color color = count > 15 ? Colors.red : (count > 5 ? Colors.orange : Colors.green);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            "LIVE: $count ACTIVE SPOTS",
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, String growth) {
    bool isPositive = growth.startsWith('+');
    return Expanded(
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(growth, style: TextStyle(color: isPositive ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard({required String title, required String subtitle, required Widget chart}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 40),
            SizedBox(height: 300, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Padding(padding: const EdgeInsets.only(top: 10), child: Text(days[value.toInt()], style: const TextStyle(color: Colors.grey, fontSize: 12)));
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text('${value.toInt()}k', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 3.5),
              const FlSpot(1, 1.8),
              const FlSpot(2, 5.0),
              const FlSpot(3, 4.2),
              const FlSpot(4, 6.8),
              const FlSpot(5, 5.5),
              const FlSpot(6, 8.2),
            ],
            isCurved: true,
            color: const Color(0xFF2563EB),
            barWidth: 5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true, 
              gradient: LinearGradient(
                colors: [const Color(0xFF2563EB).withOpacity(0.2), const Color(0xFF2563EB).withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        sectionsSpace: 0,
        centerSpaceRadius: 50,
        sections: [
          PieChartSectionData(value: 65, color: const Color(0xFF2563EB), title: '65%', radius: 25, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          PieChartSectionData(value: 20, color: const Color(0xFF10B981), title: '20%', radius: 25, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          PieChartSectionData(value: 15, color: const Color(0xFFF59E0B), title: '15%', radius: 25, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 20,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                return Text(days[value.toInt()], style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeGroupData(0, 12, Colors.blue.shade300),
          _makeGroupData(1, 15, Colors.blue.shade300),
          _makeGroupData(2, 11, Colors.blue.shade300),
          _makeGroupData(3, 18, Colors.blue),
          _makeGroupData(4, 14, Colors.blue.shade300),
          _makeGroupData(5, 9, Colors.blue.shade300),
          _makeGroupData(6, 7, Colors.blue.shade300),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 22,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
        ),
      ],
    );
  }
}
