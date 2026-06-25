// CONFIGURARE TARIFE DINAMICE (CERINȚA 1)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';

class PricingConfigScreen extends StatefulWidget {
  const PricingConfigScreen({super.key});

  @override
  State<PricingConfigScreen> createState() => _PricingConfigScreenState();
}

class _PricingConfigScreenState extends State<PricingConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  // Local controllers for input
  final TextEditingController _weekendSurge = TextEditingController();
  final TextEditingController _nightDiscount = TextEditingController();
  final TextEditingController _peakHourSurge = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Dynamic Pricing Config')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: adminService.pricingSettingsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          // Prefill if not editing
          if (_weekendSurge.text.isEmpty) _weekendSurge.text = (data['weekendSurge'] ?? 1.2).toString();
          if (_nightDiscount.text.isEmpty) _nightDiscount.text = (data['nightDiscount'] ?? 0.8).toString();
          if (_peakHourSurge.text.isEmpty) _peakHourSurge.text = (data['peakHourSurge'] ?? 1.5).toString();

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildConfigCard(
                  title: 'Weekend Surge Multiplier',
                  controller: _weekendSurge,
                  icon: Icons.weekend,
                  subtitle: 'Multiplier applied on Sat & Sun',
                ),
                const SizedBox(height: 16),
                _buildConfigCard(
                  title: 'Night Discount',
                  controller: _nightDiscount,
                  icon: Icons.nightlight_round,
                  subtitle: 'Multiplier applied between 22:00 - 06:00',
                ),
                const SizedBox(height: 16),
                _buildConfigCard(
                  title: 'Peak Hours Multiplier',
                  controller: _peakHourSurge,
                  icon: Icons.trending_up,
                  subtitle: 'Multiplier for high-demand periods',
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      await adminService.updatePricingSettings({
                        'weekendSurge': double.parse(_weekendSurge.text),
                        'nightDiscount': double.parse(_nightDiscount.text),
                        'peakHourSurge': double.parse(_peakHourSurge.text),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pricing updated!')));
                      }
                    }
                  },
                  child: const Text('Save Configuration', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfigCard({required String title, required TextEditingController controller, required IconData icon, required String subtitle}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: 'x',
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
    );
  }
}