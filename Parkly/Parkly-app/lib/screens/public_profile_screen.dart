import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/parking_space.dart';
import '../services/parking_service.dart';
import '../services/language_service.dart';
import 'parking_details_screen.dart';
import 'chat_conversation_screen.dart';

class PublicProfileScreen extends StatelessWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    final parkingService = ParkingService();

    return ListenableBuilder(
      listenable: lang,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(lang.translate('owner_profile'),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          body: StreamBuilder<DocumentSnapshot>(
            stream: userId == 'parkly_support' 
              ? null // Nu avem nevoie de stream pentru support, definim datele mai jos
              : FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
            builder: (context, userSnapshot) {
              String name = 'User';
              String email = '';
              String? photoURL;

              if (userId == 'parkly_support') {
                name = 'Echipa Parkly';
                email = 'support@parkly.ro';
                // Folosim logo-ul ca poză de profil
              } else {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const Center(child: Text("Utilizator negăsit"));
                }
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                name = userData['displayName'] ?? userData['name'] ?? 'User';
                email = userData['email'] ?? '';
                photoURL = userData['photoURL'];
              }

              return CustomScrollView(
                slivers: [
                  // Profile Header
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      color: Colors.white,
                      child: Column(
                        children: [
                          userId == 'parkly_support'
                            ? Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade100),
                                  image: const DecorationImage(
                                    image: AssetImage('lib/assets/logo.png'),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                radius: 50,
                                backgroundColor: const Color(0xFF2563EB),
                                backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                                child: photoURL == null
                                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))
                                    : null,
                              ),
                          const SizedBox(height: 16),
                          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatConversationScreen(
                                    receiverId: userId,
                                    receiverName: name,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(
                              userId == 'parkly_support' ? Icons.support_agent_rounded : Icons.chat_bubble_outline, 
                              size: 18, 
                              color: Colors.white
                            ),
                            label: Text(
                              userId == 'parkly_support' ? lang.translate('contact_support_btn') : lang.translate('chat_with_owner'), 
                              style: const TextStyle(color: Colors.white)
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Posted Spots Header
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        userId == 'parkly_support' ? lang.translate('official_parkly_spots') : lang.translate('owner_spots'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Posted Spots List
                  StreamBuilder<List<ParkingSpace>>(
                    stream: parkingService.getParkingSpaces(),
                    builder: (context, spotsSnapshot) {
                      if (!spotsSnapshot.hasData) {
                        return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                      }

                      // Filtrăm doar locurile acestui user care sunt disponibile
                      // Pentru support (Echipa Parkly), ownerId este empty string în baza de date
                      final ownerSpots = spotsSnapshot.data!.where((s) {
                        if (userId == 'parkly_support') {
                          return s.ownerId.isEmpty && s.isAvailable;
                        }
                        return s.ownerId == userId && s.isAvailable;
                      }).toList();

                      if (ownerSpots.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Center(
                              child: Text(lang.translate('no_available_spots_owner'),
                                  style: const TextStyle(color: Colors.grey)),
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final space = ownerSpots[index];
                              return _buildSpotCard(context, space, lang);
                            },
                            childCount: ownerSpots.length,
                          ),
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 50)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSpotCard(BuildContext context, ParkingSpace space, LanguageService lang) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ParkingDetailsScreen(parkingSpace: space))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                space.getAllDisplayImages().first,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(width: 70, height: 70, color: Colors.grey.shade100, child: const Icon(Icons.image_not_supported)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(space.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(space.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text("${space.pricePerHour.toInt()} lei/${lang.translate('hour_short')}", 
                    style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
