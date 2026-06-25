import 'package:flutter/material.dart';
import 'dart:async';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'admin_screen.dart';
import 'profile_screen.dart';
import 'chats_list_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parkly/services/language_service.dart';
import '../services/database_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  String? _userRole;
  final lang = LanguageService();
  final DatabaseService _dbService = DatabaseService();
  Timer? _presenceTimer;

  String? get userRole => _userRole;

  bool get isAdmin => 
    _userRole != null && 
    (['admin', 'owner', 'proprietar', 'partner'].contains(_userRole!.toLowerCase()));

  void setIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToUserRole();
    _startPresenceUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _dbService.updatePresence();
      _startPresenceUpdates();
    } else {
      _presenceTimer?.cancel();
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        _dbService.setOffline();
      }
    }
  }

  void _startPresenceUpdates() {
    _presenceTimer?.cancel();
    _dbService.updatePresence();
    // Update la fiecare 2 minute cât timp aplicația e deschisă
    _presenceTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _dbService.updatePresence();
    });
  }

  void _listenToUserRole() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
        if (mounted && doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final String? role = data['role'];
          debugPrint("DEBUG: User Role loaded: $role for UID: ${user.uid}");
          setState(() {
            _userRole = role;
          });
        } else {
          debugPrint("DEBUG: User document not found or role missing.");
        }
      });
    } else {
      debugPrint("DEBUG: No user logged in.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lang,
      builder: (context, child) {
        // Definim ecranele (5 la număr)
        final List<Widget> screens = [
          const DashboardScreen(),
          const HistoryScreen(),
          const ChatsListScreen(),
          const AdminScreen(),
          const ProfileScreen(),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            selectedItemColor: const Color(0xFF2563EB),
            unselectedItemColor: Colors.grey.shade400,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.grid_view_rounded),
                activeIcon: const Icon(Icons.grid_view_rounded),
                label: lang.translate('nav_home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.history_rounded),
                activeIcon: const Icon(Icons.history_rounded),
                label: lang.translate('nav_history'),
              ),
              BottomNavigationBarItem(
                icon: StreamBuilder<QuerySnapshot>(
                  // Numărăm doar chat-urile necitite pentru tab-ul de jos
                  stream: FirebaseFirestore.instance.collection('chats')
                    .where('unreadBy', arrayContains: FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                  builder: (context, snapshot) {
                    bool hasUnreadChats = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                    return Badge(
                      isLabelVisible: hasUnreadChats,
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.chat_bubble_outline_rounded),
                    );
                  },
                ),
                activeIcon: const Icon(Icons.chat_bubble_rounded),
                label: lang.translate('nav_messages'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.admin_panel_settings_rounded),
                activeIcon: const Icon(Icons.admin_panel_settings_rounded),
                label: lang.translate('nav_admin'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline_rounded),
                activeIcon: const Icon(Icons.person_rounded),
                label: lang.translate('nav_profile'),
              ),
            ],
          ),
        );
      },
    );
  }
}
