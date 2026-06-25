import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/config_service.dart';

class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  final _weekendController = TextEditingController();
  final _nightController = TextEditingController();
  final _peakController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final config = ConfigService();
    _weekendController.text = config.weekendMultiplier.toString();
    _nightController.text = config.nightMultiplier.toString();
    _peakController.text = config.peakMultiplier.toString();
  }

  @override
  void dispose() {
    _weekendController.dispose();
    _nightController.dispose();
    _peakController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('pricing').set({
        'weekendSurge': double.tryParse(_weekendController.text) ?? 1.0,
        'nightDiscount': double.tryParse(_nightController.text) ?? 1.0,
        'peakHourSurge': double.tryParse(_peakController.text) ?? 1.0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurație salvată cu succes!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Dynamic Pricing Config', 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildConfigCard(
              'Weekend Surge Multiplier',
              'Multiplier applied on Sat & Sun',
              Icons.weekend,
              _weekendController,
            ),
            const SizedBox(height: 20),
            _buildConfigCard(
              'Night Discount',
              'Multiplier applied between 22:00 - 06:00',
              Icons.nightlight_round,
              _nightController,
            ),
            const SizedBox(height: 20),
            _buildConfigCard(
              'Peak Hours Multiplier',
              'Multiplier for high-demand periods',
              Icons.trending_up,
              _peakController,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveConfig,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Configuration', 
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Note: Multipliers are compounded (e.g., Weekend * Night). A value of 1.0 means no change.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard(String title, String subtitle, IconData icon, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8F9FB),
              prefixIcon: const Icon(Icons.calculate_outlined, color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
