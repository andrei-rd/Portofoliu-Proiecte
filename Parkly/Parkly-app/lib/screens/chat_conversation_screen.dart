import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:async';
import '../services/chat_service.dart';
import '../services/language_service.dart';
import 'public_profile_screen.dart';

class ChatConversationScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatConversationScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isUploading = false;

  // States for Reply and Edit
  Map<String, dynamic>? _replyMessage;
  String? _editingMessageId;

  // Search and Typing
  bool _isSearching = false;
  String _searchQuery = "";
  Timer? _typingTimer;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _markChatAsRead();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _typingTimer?.cancel();
    _positionSubscription?.cancel();
    _chatService.setTypingStatus(widget.receiverId, false);
    super.dispose();
  }

  void _onTextChanged() {
    if (_messageController.text.isNotEmpty) {
      if (_typingTimer == null || !_typingTimer!.isActive) {
        _chatService.setTypingStatus(widget.receiverId, true);
      }
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _chatService.setTypingStatus(widget.receiverId, false);
      });
    } else {
      _chatService.setTypingStatus(widget.receiverId, false);
    }
  }

  void _markChatAsRead() {
    String chatRoomId = _chatService.getChatRoomId(currentUserId, widget.receiverId);
    _chatService.markAsRead(chatRoomId);
  }

  void _sendMessage() {
    final String text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_editingMessageId != null) {
      _chatService.editMessage(widget.receiverId, _editingMessageId!, text);
      setState(() {
        _editingMessageId = null;
      });
    } else {
      _chatService.sendMessage(widget.receiverId, text, replyTo: _replyMessage);
      setState(() {
        _replyMessage = null;
      });
    }
    _messageController.clear();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        await _chatService.sendFileMessage(widget.receiverId, File(pickedFile.path), 'image', replyTo: _replyMessage);
        setState(() {
          _replyMessage = null;
        });
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isUploading = true);
      try {
        final file = File(result.files.single.path!);
        await _chatService.sendFileMessage(widget.receiverId, file, 'document', replyTo: _replyMessage);
        setState(() {
          _replyMessage = null;
        });
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _shareLocation({bool isLive = false}) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    
    if (isLive) {
      // Trimitem mesajul inițial
      final chatRoomId = _chatService.getChatRoomId(currentUserId, widget.receiverId);
      final docRef = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'receiverId': widget.receiverId,
        'message': 'Locație în timp real',
        'type': 'live_location',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'isLiveActive': true,
      });

      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)
      ).listen((pos) {
        _chatService.updateLiveLocationCoords(widget.receiverId, docRef.id, pos.latitude, pos.longitude);
      });
    } else {
      _chatService.sendLocationMessage(widget.receiverId, position.latitude, position.longitude);
    }
  }

  void _showAttachmentMenu() {
    final lang = LanguageService();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                title: Text(lang.currentLocale.languageCode == 'ro' ? 'Cameră Foto' : 'Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB)),
                title: Text(lang.currentLocale.languageCode == 'ro' ? 'Galerie Foto' : 'Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on_rounded, color: Color(0xFF2563EB)),
                title: Text(lang.currentLocale.languageCode == 'ro' ? 'Trimite Locația' : 'Send Location'),
                onTap: () {
                  Navigator.pop(context);
                  _shareLocation(isLive: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.near_me_rounded, color: Colors.green),
                title: Text(lang.currentLocale.languageCode == 'ro' ? 'Partajează Locația Live' : 'Share Live Location'),
                onTap: () {
                  Navigator.pop(context);
                  _shareLocation(isLive: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_rounded, color: Color(0xFF2563EB)),
                title: Text(lang.currentLocale.languageCode == 'ro' ? 'Document' : 'Document'),
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOptions(BuildContext context, String messageId, Map<String, dynamic> data, bool isMe) {
    final lang = LanguageService();
    final text = data['message'] ?? data['text'] ?? '';
    final bool isImage = data['type'] == 'image' || (text.startsWith('http') && (text.contains('.jpg') || text.contains('.png') || text.contains('.jpeg') || text.contains('firebasestorage')));
    
    final Timestamp? ts = data['timestamp'] as Timestamp?;
    final bool canEdit = isMe && ts != null && DateTime.now().difference(ts.toDate()).inMinutes < 5;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) => 
                    GestureDetector(
                      onTap: () {
                        _chatService.addReaction(widget.receiverId, messageId, emoji);
                        Navigator.pop(context);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 30)),
                    )
                  ).toList(),
                ),
              ),
              const Divider(),
              if (!isImage)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: Text(lang.currentLocale.languageCode == 'ro' ? 'Copiază' : 'Copy'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.currentLocale.languageCode == 'ro' ? 'Mesaj copiat' : 'Message copied')));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: Text(lang.currentLocale.languageCode == 'ro' ? 'Răspunde' : 'Reply'),
                onTap: () {
                  setState(() {
                    _replyMessage = data;
                    _editingMessageId = null;
                  });
                  Navigator.pop(context);
                },
              ),
              if (isImage)
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: Text(lang.currentLocale.languageCode == 'ro' ? 'Descarcă' : 'Download'),
                  onTap: () async {
                    Navigator.pop(context);
                    final Uri url = Uri.parse(text);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              if (canEdit && !isImage)
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: Text(lang.currentLocale.languageCode == 'ro' ? 'Editează' : 'Edit'),
                  onTap: () {
                    setState(() {
                      _messageController.text = text;
                      _editingMessageId = messageId;
                      _replyMessage = null;
                    });
                    Navigator.pop(context);
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: Text(lang.currentLocale.languageCode == 'ro' ? 'Șterge' : 'Delete', style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    _showDeleteConfirm(context, messageId);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(BuildContext context, String messageId) {
    final lang = LanguageService();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.currentLocale.languageCode == 'ro' ? 'Șterge mesajul?' : 'Delete message?'),
        content: Text(lang.currentLocale.languageCode == 'ro' ? 'Această acțiune este permanentă.' : 'This action is permanent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(lang.translate('cancel'))),
          TextButton(
            onPressed: () {
              _chatService.deleteMessage(widget.receiverId, messageId);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close bottom sheet
            },
            child: Text(lang.translate('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getStatusText(Map<String, dynamic>? userData, LanguageService lang) {
    if (widget.receiverId == 'parkly_support') {
      return lang.currentLocale.languageCode == 'ro' ? 'Online' : 'Online';
    }
    if (userData == null) return '';

    final bool isOnline = userData['isOnline'] ?? false;
    final Timestamp? lastSeenTs = userData['lastSeen'] as Timestamp?;
    
    if (lastSeenTs == null) return '';

    final DateTime lastSeen = lastSeenTs.toDate();
    final DateTime now = DateTime.now();
    final difference = now.difference(lastSeen);

    // Dacă e marcat online și activitatea e de acum maxim 5 minute
    if (isOnline && difference.inMinutes < 5) {
      return lang.currentLocale.languageCode == 'ro' ? 'Online' : 'Online';
    }

    // Altfel calculăm de cât timp e offline
    if (difference.inMinutes < 1) {
      return lang.currentLocale.languageCode == 'ro' ? 'Offline acum' : 'Offline just now';
    } else if (difference.inMinutes < 60) {
      return lang.currentLocale.languageCode == 'ro' 
          ? 'Offline de ${difference.inMinutes}m' 
          : 'Offline for ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return lang.currentLocale.languageCode == 'ro' 
          ? 'Offline de ${difference.inHours}h' 
          : 'Offline for ${difference.inHours}h';
    } else {
      return lang.currentLocale.languageCode == 'ro' 
          ? 'Offline de ${difference.inDays}z' 
          : 'Offline for ${difference.inDays}d';
    }
  }

  Widget _buildLocationContent(Map<String, dynamic> data, String messageId, bool isMe, LanguageService lang) {
    final double lat = data['latitude'] ?? 0.0;
    final double lng = data['longitude'] ?? 0.0;
    final bool isLive = data['type'] == 'live_location';
    final bool isLiveActive = data['isLiveActive'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: AssetImage('lib/assets/main.jpeg'),
                fit: BoxFit.cover,
                opacity: 0.5,
              ),
            ),
            child: Center(
              child: Icon(isLive ? Icons.near_me_rounded : Icons.location_on_rounded, 
                  color: isMe ? Colors.white : const Color(0xFF2563EB), size: 40),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isLive ? (isLiveActive ? "Locație în timp real" : "Locație live oprită") : "Locație trimisă",
                style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.black87, fontSize: 13),
              ),
              if (isLive && isLiveActive && isMe)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _positionSubscription?.cancel();
                        _chatService.stopLiveLocation(widget.receiverId, messageId);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white, elevation: 0),
                      child: const Text("Oprește partajarea", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    String chatRoomId =
        _chatService.getChatRoomId(currentUserId, widget.receiverId);

    return ListenableBuilder(
      listenable: lang,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            titleSpacing: 0,
            title: _isSearching 
              ? TextField(
                  autofocus: true,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: lang.translate('search_hint'),
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                )
              : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.receiverId).snapshots(),
              builder: (context, userSnapshot) {
                String? photoURL;
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  photoURL = (userSnapshot.data!.data() as Map<String, dynamic>)['photoURL'];
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PublicProfileScreen(userId: widget.receiverId),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF2563EB),
                        backgroundImage: widget.receiverId == 'parkly_support'
                            ? const AssetImage('lib/assets/main.jpeg')
                            : (photoURL != null ? NetworkImage(photoURL) : null),
                        child: (photoURL == null && widget.receiverId != 'parkly_support')
                            ? Text(widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.receiverId == 'parkly_support' ? 'Echipa Parkly' : widget.receiverName,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                          Builder(builder: (context) {
                            final userData = userSnapshot.hasData ? (userSnapshot.data!.data() as Map<String, dynamic>?) : null;
                            final status = _getStatusText(userData, lang);
                            final isOnline = status == 'Online';
                            
                            return Text(status,
                                style: TextStyle(
                                  fontSize: 10, 
                                  color: isOnline ? Colors.green : Colors.grey,
                                  fontWeight: isOnline ? FontWeight.bold : FontWeight.normal
                                ));
                          }),
                        ],
                      ),
                    ],
                  ),
                );
              }
            ),
            backgroundColor: Colors.white,
            elevation: 0.5,
            iconTheme: const IconThemeData(color: Colors.black),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    if (_isSearching) {
                      _isSearching = false;
                      _searchQuery = "";
                    } else {
                      _isSearching = true;
                    }
                  });
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: widget.receiverId == 'parkly_support'
                      ? FirebaseFirestore.instance
                          .collection('tickets')
                          .doc(currentUserId)
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
                          .snapshots()
                      : FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatRoomId)
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());

                    var messages = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      reverse: true, // Afișăm de jos în sus
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        var data = messages[index].data() as Map<String, dynamic>;
                        String messageId = messages[index].id;
                        
                        // Adaptăm logica pentru ambele structuri (Chat clasic și Tickets Dashboard)
                        bool isMe;
                        String text;
                        
                        if (widget.receiverId == 'parkly_support') {
                          isMe = data['sender'] == 'user';
                          text = data['text'] ?? '';
                        } else {
                          isMe = data['senderId'] == currentUserId;
                          text = data['message'] ?? '';
                        }

                        // Detecție robustă pentru imagini (chiar dacă lipsește câmpul 'type')
                        bool isImage = data['type'] == 'image';
                        if (!isImage && data['type'] != 'document' && (text.startsWith('http') && (text.contains('.jpg') || text.contains('.png') || text.contains('.jpeg')))) {
                          isImage = true;
                        }

                        if (_isSearching && _searchQuery.isNotEmpty && !text.toLowerCase().contains(_searchQuery)) {
                          return const SizedBox.shrink();
                        }

                        final replyTo = data['replyTo'] as Map<String, dynamic>?;

                        return Align(
                          alignment:
                              isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () => _showOptions(context, messageId, data, isMe),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75),
                              padding: isImage
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFF2563EB) : (widget.receiverId == 'parkly_support' ? Colors.grey.shade100 : Colors.white),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                                  bottomRight: Radius.circular(isMe ? 0 : 16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 5)
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (replyTo != null)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border(left: BorderSide(color: isMe ? Colors.white : const Color(0xFF2563EB), width: 3)),
                                      ),
                                      child: Text(
                                        replyTo['message'] ?? replyTo['text'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : Colors.grey.shade600),
                                      ),
                                    ),
                                  if (isImage)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        text,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, progress) {
                                          if (progress == null) return child;
                                          return const Padding(
                                            padding: EdgeInsets.all(20.0),
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2, color: Colors.white),
                                          );
                                        },
                                      ),
                                    )
                                  else if (data['type'] == 'document')
                                    GestureDetector(
                                      onTap: () async {
                                        final Uri url = Uri.parse(text);
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isMe ? Colors.white24 : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.insert_drive_file_rounded, color: isMe ? Colors.white : const Color(0xFF2563EB)),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                'Document.${text.split('.').last.split('?').first}',
                                                style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else if (data['type'] == 'location' || data['type'] == 'live_location')
                                    _buildLocationContent(data, messageId, isMe, lang)
                                  else
                                    Text(
                                      text,
                                      style: TextStyle(
                                          color: isMe ? Colors.white : Colors.black87),
                                    ),
                                  if (isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Icon(
                                        data['seen'] == true ? Icons.done_all : Icons.done,
                                        size: 12,
                                        color: data['seen'] == true ? Colors.lightBlueAccent : Colors.white70,
                                      ),
                                    ),
                                  if (data['isEdited'] == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        lang.currentLocale.languageCode == 'ro' ? 'editat' : 'edited',
                                        style: TextStyle(fontSize: 9, color: isMe ? Colors.white60 : Colors.grey),
                                      ),
                                    ),
                                  if (data['reactions'] != null)
                                    Builder(builder: (context) {
                                      final reactions = data['reactions'] as Map<String, dynamic>;
                                      return Wrap(
                                        children: reactions.values.map((emoji) => 
                                          Container(
                                            margin: const EdgeInsets.only(top: 4, right: 4),
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(emoji.toString(), style: const TextStyle(fontSize: 12)),
                                          )
                                        ).toList(),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              if (_isUploading)
                const LinearProgressIndicator(minHeight: 2, color: Color(0xFF2563EB), backgroundColor: Colors.white),

              // Reply UI
              if (_replyMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.reply_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.currentLocale.languageCode == 'ro' ? 'Răspunzi la:' : 'Replying to:',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                            ),
                            Text(
                              _replyMessage!['message'] ?? _replyMessage!['text'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _replyMessage = null),
                      ),
                    ],
                  ),
                ),

              // Editing UI
              if (_editingMessageId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lang.currentLocale.languageCode == 'ro' ? 'Editezi mesajul...' : 'Editing message...',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() {
                          _editingMessageId = null;
                          _messageController.clear();
                        }),
                      ),
                    ],
                  ),
                ),

              // Mesaj input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        top: BorderSide(color: Colors.grey.shade200))),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.grey),
                      onPressed: _showAttachmentMenu,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: lang.currentLocale.languageCode == 'ro'
                              ? 'Scrie un mesaj...'
                              : 'Type a message...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon:
                          Icon(_editingMessageId != null ? Icons.check_circle_rounded : Icons.send_rounded, color: const Color(0xFF2563EB)),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
