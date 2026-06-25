import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'package:parkly/services/language_service.dart';
import 'wallet_screen.dart';
import 'invoices_screen.dart';
import 'account_settings_screen.dart';
import 'help_support_screen.dart';
import 'notification_settings_screen.dart';
import 'public_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final AuthService authService = AuthService();
    final DatabaseService dbService = DatabaseService();
    final lang = LanguageService();

    return ListenableBuilder(
      listenable: lang,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            title: Text(lang.translate('profile_title'),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          body: StreamBuilder<DocumentSnapshot>(
            stream: dbService.getUserData(user?.uid ?? ''),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              String name = 'User';
              String email = user?.email ?? '';
              String? photoURL;

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                name = data['displayName'] ?? data['name'] ?? 'User';
                photoURL = data['photoURL'];
              }

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                  await Future.delayed(const Duration(seconds: 1));
                },
                color: const Color(0xFF2563EB),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Card
                      GestureDetector(
                        onTap: () {
                          if (user?.uid != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PublicProfileScreen(userId: user!.uid),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      gradient: photoURL == null
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFF2563EB),
                                                Color(0xFF1D4ED8)
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      borderRadius: BorderRadius.circular(35),
                                      image: photoURL != null
                                          ? DecorationImage(
                                              image: NetworkImage(photoURL),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: photoURL == null
                                        ? Center(
                                            child: Text(
                                              name.isNotEmpty
                                                  ? name[0].toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 30,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(email,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // My Cars Section
                      _buildSectionHeader(lang.translate('my_cars'),
                          onAdd: () => _showAddCarDialog(
                              context, dbService, user?.uid ?? '', lang),
                          lang: lang),

                      StreamBuilder<QuerySnapshot>(
                        stream: dbService.getUserCars(user?.uid ?? ''),
                        builder: (context, carSnapshot) {
                          if (!carSnapshot.hasData ||
                              carSnapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text(lang.translate('no_cars_yet')),
                              ),
                            );
                          }
                          return Column(
                            children: carSnapshot.data!.docs.map((doc) {
                              final car = doc.data() as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildCarCard(
                                    car['model'] ?? '',
                                    car['plate'] ?? '',
                                    () => _showCarDetailsDialog(
                                        context,
                                        dbService,
                                        user?.uid ?? '',
                                        doc.id,
                                        car,
                                        lang)),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 25),

                      // Settings
                      Text(lang.translate('settings'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _buildSettingsTile(Icons.credit_card,
                                lang.translate('payment_methods'), onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const WalletScreen()),
                              );
                            }),
                            _buildSettingsTile(Icons.receipt_long,
                                lang.translate('invoices_title'), onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const InvoicesScreen()),
                              );
                            }),
                            _buildSettingsTile(Icons.notifications_none,
                                lang.translate('notifications'), onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const NotificationSettingsScreen()),
                              );
                            }),
                            _buildSettingsTile(
                                Icons.help_outline, lang.translate('support'),
                                onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const HelpAndSupportScreen()),
                              );
                            }),
                            _buildSettingsTile(
                                Icons.language, lang.translate('language'),
                                onTap: () {
                              _showLanguagePicker(context, lang);
                            }),
                            _buildSettingsTile(
                                Icons.security, lang.translate('security'),
                                isLast: true, onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const AccountSettingsScreen()),
                               );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => authService.signOut(),
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: Text(lang.translate('logout'),
                              style: const TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: BorderSide(color: Colors.grey.shade200),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title,
      {VoidCallback? onAdd, required LanguageService lang}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: onAdd, child: Text(lang.translate('add'))),
      ],
    );
  }

  Widget _buildCarCard(String model, String plate, VoidCallback onTap) {
    String brandLogo = _getLogoForBrand(model);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child: brandLogo.isNotEmpty
                  ? Image.network(
                      brandLogo,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.directions_car, color: Colors.grey),
                    )
                  : const Icon(Icons.directions_car, color: Colors.grey),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(model,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(plate,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _getLogoForBrand(String model) {
    final m = model.toLowerCase();
    if (m.contains('dacia')) return 'https://logo.clearbit.com/dacia.ro';
    if (m.contains('skoda')) return 'https://logo.clearbit.com/skoda-auto.com';
    if (m.contains('volkswagen') || m.contains('vw')) {
      return 'https://logo.clearbit.com/volkswagen.com';
    }
    if (m.contains('bmw')) return 'https://logo.clearbit.com/bmw.com';
    if (m.contains('audi')) return 'https://logo.clearbit.com/audi.com';
    if (m.contains('mercedes')) {
      return 'https://logo.clearbit.com/mercedes-benz.com';
    }
    if (m.contains('ford')) return 'https://logo.clearbit.com/ford.com';
    if (m.contains('toyota')) return 'https://logo.clearbit.com/toyota.com';
    if (m.contains('hyundai')) return 'https://logo.clearbit.com/hyundai.com';
    if (m.contains('renault')) return 'https://logo.clearbit.com/renault.ro';
    if (m.contains('tesla')) return 'https://logo.clearbit.com/tesla.com';
    return '';
  }

  Widget _buildSettingsTile(IconData icon, String title,
      {bool isLast = false, VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey.shade700, size: 22),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
        onTap: onTap ?? () {},
      ),
    );
  }

  void _showCarDetailsDialog(
      BuildContext context,
      DatabaseService db,
      String uid,
      String carId,
      Map<String, dynamic> car,
      LanguageService lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car,
                size: 50, color: Color(0xFF2563EB)),
            const SizedBox(height: 15),
            Text(car['model'] ?? '',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(car['plate'] ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const Divider(height: 40),
            _buildDetailRow(lang.translate('vin'), car['vin'] ?? 'N/A'),
            const SizedBox(height: 10),
            _buildDetailRow(
                lang.translate('pollution_norm'), car['emission'] ?? 'N/A'),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditCarDialog(context, db, uid, carId, car, lang);
                    },
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: Text(lang.translate('edit'),
                        style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await db.deleteUserCar(uid, carId);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: Text(lang.translate('delete'),
                        style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.grey, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showEditCarDialog(BuildContext context, DatabaseService db, String uid,
      String carId, Map<String, dynamic> car, LanguageService lang) {
    final modelController = TextEditingController(text: car['model']);
    final plateController = TextEditingController(text: car['plate']);
    final vinController = TextEditingController(text: car['vin']);
    final emissionController = TextEditingController(text: car['emission']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('edit_car')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: modelController,
                  decoration:
                      InputDecoration(labelText: lang.translate('model_hint'))),
              TextField(
                  controller: plateController,
                  decoration:
                      InputDecoration(labelText: lang.translate('plate_hint'))),
              TextField(
                  controller: vinController,
                  decoration:
                      InputDecoration(labelText: lang.translate('vin'))),
              const SizedBox(height: 10),
              Text(lang.translate('pollution_norm'),
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 10),
              StatefulBuilder(builder: (context, setDialogState) {
                return Wrap(
                  spacing: 10,
                  children: ['E3', 'E4', 'E5', 'E6'].map((norm) {
                    final isSelected = emissionController.text == norm;
                    return ChoiceChip(
                      label: Text(norm,
                          style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF2563EB),
                      onSelected: (selected) {
                        setDialogState(() {
                          emissionController.text = norm;
                        });
                      },
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.translate('cancel'))),
          ElevatedButton(
            onPressed: () async {
              await db.updateUserCar(
                  uid,
                  carId,
                  modelController.text,
                  plateController.text,
                  vinController.text,
                  emissionController.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(lang.translate('save')),
          ),
        ],
      ),
    );
  }

  void _showAddCarDialog(BuildContext context, DatabaseService db, String uid,
      LanguageService lang) {
    final modelController = TextEditingController();
    final plateController = TextEditingController();
    final vinController = TextEditingController();
    final emissionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('add_car')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: modelController,
                  decoration:
                      InputDecoration(labelText: lang.translate('model_hint'))),
              TextField(
                  controller: plateController,
                  decoration:
                      InputDecoration(labelText: lang.translate('plate_hint'))),
              TextField(
                  controller: vinController,
                  decoration:
                      InputDecoration(labelText: lang.translate('vin'))),
              const SizedBox(height: 10),
              Text(lang.translate('pollution_norm'),
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 10),
              StatefulBuilder(builder: (context, setDialogState) {
                return Wrap(
                  spacing: 10,
                  children: ['E3', 'E4', 'E5', 'E6'].map((norm) {
                    final isSelected = emissionController.text == norm;
                    return ChoiceChip(
                      label: Text(norm,
                          style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF2563EB),
                      onSelected: (selected) {
                        setDialogState(() {
                          emissionController.text = norm;
                        });
                      },
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.translate('cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (modelController.text.isNotEmpty &&
                  plateController.text.isNotEmpty) {
                await db.addUserCar(
                    uid,
                    modelController.text,
                    plateController.text,
                    vinController.text,
                    emissionController.text);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text(lang.translate('add')),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, LanguageService lang) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.translate('select_language'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Text('🇷🇴', style: TextStyle(fontSize: 24)),
                title: const Text('Română'),
                trailing: lang.currentLocale.languageCode == 'ro'
                    ? const Icon(Icons.check_circle, color: Color(0xFF2563EB))
                    : null,
                onTap: () {
                  lang.changeLanguage('ro');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
                title: const Text('English'),
                trailing: lang.currentLocale.languageCode == 'en'
                    ? const Icon(Icons.check_circle, color: Color(0xFF2563EB))
                    : null,
                onTap: () {
                  lang.changeLanguage('en');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
