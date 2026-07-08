import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:delivery_manager_interface/models/chat_room_model.dart';
import 'package:delivery_manager_interface/models/message_model.dart';
import 'package:delivery_manager_interface/models/user_model.dart';
import 'package:delivery_manager_interface/models/order_model.dart';
import 'package:delivery_manager_interface/models/delivery_manager_model.dart';
import 'package:delivery_manager_interface/services/chat_service.dart';
import 'package:delivery_manager_interface/core/localization.dart';

class CustomerInquiriesWidget extends StatefulWidget {
  final String uid;
  final List<MyOrder> orders;

  const CustomerInquiriesWidget({
    super.key,
    required this.uid,
    required this.orders,
  });

  @override
  State<CustomerInquiriesWidget> createState() =>
      _CustomerInquiriesWidgetState();
}

class _CustomerInquiriesWidgetState extends State<CustomerInquiriesWidget> {
  final ChatService _chatService = ChatService();
  final Map<String, MyUser> _userCache = {};
  final Map<String, Future<DocumentSnapshot>> _userFetchFutures = {};
  
  late Stream<List<ChatRoomModel>> _chatRoomsStream;
  Stream<List<MessageModel>>? _messagesStream;

  String? _selectedChatRoomId;
  ChatRoomModel? _selectedChatRoom;
  String _selectedTab = 'ongoing'; // 'ongoing' or 'completed'
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  XFile? _pickedImage;
  bool _isSending = false;
  String _managerName = '';

  @override
  void initState() {
    super.initState();
    _initChatRoomsStream();
    _loadManagerName();
  }

  Future<void> _loadManagerName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('deliveryManagers')
          .doc(widget.uid)
          .get();
      if (doc.exists && doc.data() != null && mounted) {
        final manager = DeliveryManagerModel.fromMap(doc.data()!);
        setState(() {
          _managerName = manager.name;
        });
      }
    } catch (_) {}
  }

  void _initChatRoomsStream() {
    _chatRoomsStream = FirebaseFirestore.instance
        .collection('chatRooms')
        .where('participants', arrayContains: widget.uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ChatRoomModel.fromMap(doc.data()))
                  .toList(),
        );
  }

  @override
  void didUpdateWidget(CustomerInquiriesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _initChatRoomsStream();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedImage = picked;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_selectedChatRoomId == null) return;
    final content = _messageController.text.trim();
    if (content.isEmpty && _pickedImage == null) return;

    setState(() => _isSending = true);

    try {
      String? imageUrl;
      if (_pickedImage != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${widget.uid}.jpg';
        final ref = FirebaseStorage.instance.ref().child(
          'chat_images/$fileName',
        );

        if (kIsWeb) {
          final bytes = await _pickedImage!.readAsBytes();
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        } else {
          await ref.putFile(File(_pickedImage!.path));
        }
        imageUrl = await ref.getDownloadURL();
      }

      final messageRef =
          FirebaseFirestore.instance.collection('messages').doc();
      final messageId = messageRef.id;

      final message = MessageModel(
        id: messageId,
        chatRoomId: _selectedChatRoomId!,
        senderId: widget.uid,
        senderName: _managerName.isNotEmpty ? _managerName : '매니저',
        content: content,
        imageUrl: imageUrl ?? '',
        timestamp: DateTime.now(),
        readBy: [widget.uid],
        lovedBy: [],
        deletedBy: [],
      );

      await messageRef.set(message.toMap());

      // Update last message in chat room
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(_selectedChatRoomId)
          .update({
            'lastMessage':
                content.isNotEmpty ? content : tr('photo_sent_label'),
            'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
            'lastMessageSenderId': widget.uid,
          });

      _messageController.clear();
      setState(() {
        _pickedImage = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('메시지 전송 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _toggleChatRoomStatus(
    String roomId,
    String currentStatus,
  ) async {
    final newStatus = currentStatus == 'completed' ? 'ongoing' : 'completed';
    await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).update(
      {'status': newStatus},
    );
    setState(() {
      if (_selectedChatRoom != null && _selectedChatRoom!.id == roomId) {
        _selectedChatRoom = ChatRoomModel(
          id: _selectedChatRoom!.id,
          name: _selectedChatRoom!.name,
          type: _selectedChatRoom!.type,
          participants: _selectedChatRoom!.participants,
          lastMessage: _selectedChatRoom!.lastMessage,
          lastMessageTime: _selectedChatRoom!.lastMessageTime,
          lastMessageSenderId: _selectedChatRoom!.lastMessageSenderId,
          groupImage: _selectedChatRoom!.groupImage,
          createdBy: _selectedChatRoom!.createdBy,
          createdAt: _selectedChatRoom!.createdAt,
          unreadCount: _selectedChatRoom!.unreadCount,
          deletedBy: _selectedChatRoom!.deletedBy,
          status: newStatus,
        );
      }
    });
  }

  void _selectChatRoom(ChatRoomModel room) {
    setState(() {
      _selectedChatRoomId = room.id;
      _selectedChatRoom = room;
      _messagesStream = _chatService.getMessagesStream(room.id);
    });
    _chatService.markMessagesAsRead(room.id);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left Sidebar: Chat List
        _buildSidebar(),

        // Vertical Divider
        Container(width: 1, color: Colors.grey.shade200),

        // Right: Chat Pane & User Details
        Expanded(
          child:
              _selectedChatRoomId == null
                  ? _buildEmptyState()
                  : _buildChatArea(),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return SizedBox(
      width: 340,
      child: Column(
        children: [
          // Search input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: tr('search_customer_placeholder'),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: Colors.grey,
                  ),
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 16,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // Tab selection (Ongoing vs Completed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildSidebarTab(
                    label: tr('chat_ongoing'),
                    isSelected: _selectedTab == 'ongoing',
                    onTap: () => setState(() => _selectedTab = 'ongoing'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSidebarTab(
                    label: tr('chat_completed'),
                    isSelected: _selectedTab == 'completed',
                    onTap: () => setState(() => _selectedTab = 'completed'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stream of chat rooms
          Expanded(
            child: StreamBuilder<List<ChatRoomModel>>(
              stream: _chatRoomsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allRooms = snapshot.data ?? [];

                // Filter by deleted state
                final activeRooms =
                    allRooms.where((room) {
                      return !room.deletedBy.contains(widget.uid);
                    }).toList();

                // Sort by last message time descending
                activeRooms.sort(
                  (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
                );

                return ListView.builder(
                  itemCount: activeRooms.length,
                  itemBuilder: (context, index) {
                    final room = activeRooms[index];

                    // Filter by status tab
                    final isCompleted = room.status == 'completed';
                    if (_selectedTab == 'ongoing' && isCompleted) {
                      return const SizedBox.shrink();
                    }
                    if (_selectedTab == 'completed' && !isCompleted) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      key: ValueKey(room.id),
                      child: _buildChatRoomItem(room),
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

  Widget _buildSidebarTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildChatRoomItem(ChatRoomModel room) {
    final otherUserId = room.participants.firstWhere(
      (id) => id != widget.uid,
      orElse: () => '',
    );
    if (otherUserId.isEmpty) return const SizedBox.shrink();

    if (_userCache.containsKey(otherUserId)) {
      final cachedUser = _userCache[otherUserId]!;
      if (_searchQuery.isNotEmpty &&
          !cachedUser.name.toLowerCase().contains(_searchQuery)) {
        return const SizedBox.shrink();
      }
      return _buildRoomTile(room, cachedUser);
    }

    final future = _userFetchFutures.putIfAbsent(
      otherUserId,
      () => FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
    );

    return FutureBuilder<DocumentSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final user = MyUser.fromDocument(
            snapshot.data!.data() as Map<String, dynamic>,
          );
          _userCache[otherUserId] = user;

          if (_searchQuery.isNotEmpty &&
              !user.name.toLowerCase().contains(_searchQuery)) {
            return const SizedBox.shrink();
          }
          return _buildRoomTile(room, user);
        }
        return _buildRoomTile(room, MyUser.empty);
      },
    );
  }

  Widget _buildRoomTile(ChatRoomModel room, MyUser user) {
    final isSelected = room.id == _selectedChatRoomId;
    final unreadCount = room.unreadCount[widget.uid] ?? 0;

    return InkWell(
      onTap: () => _selectChatRoom(room),
      child: Container(
        color: isSelected ? const Color(0xFFF1F2F4) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage:
                  user.url.isNotEmpty ? NetworkImage(user.url) : null,
              backgroundColor: Colors.grey[200],
              child:
                  user.url.isEmpty
                      ? Text(
                        user.name.isNotEmpty ? user.name[0] : '?',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        user.name.isNotEmpty ? user.name : tr('deleted_user'),
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'HH:mm',
                        ).format(room.lastMessageTime.toLocal()),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    room.lastMessage ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            tr('no_inquiries'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('select_chat_hint'),
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    final otherUserId = _selectedChatRoom!.participants.firstWhere(
      (id) => id != widget.uid,
      orElse: () => '',
    );
    final otherUser = _userCache[otherUserId] ?? MyUser.empty;

    return Row(
      children: [
        // Center: Chat Content
        Expanded(
          child: Column(
            children: [
              // Chat Header
              _buildChatHeader(otherUser),

              // Chat messages
              Expanded(
                child: Container(
                  color: const Color(0xFFF9F9FB),
                  child: StreamBuilder<List<MessageModel>>(
                    stream: _messagesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            tr('no_messages_hint'),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == widget.uid;
                          if (message.deletedBy.contains(widget.uid)) {
                            return const SizedBox.shrink();
                          }
                          return _buildMessageBubble(message, isMe, otherUser);
                        },
                      );
                    },
                  ),
                ),
              ),

              // Chat Input
              _buildChatInput(),
            ],
          ),
        ),

        // Vertical Divider
        Container(width: 1, color: Colors.grey.shade200),

        // Right Panel: User Details & Stats
        _buildUserDetailsPanel(otherUser),
      ],
    );
  }

  Widget _buildChatHeader(MyUser user) {
    final isCompleted = _selectedChatRoom!.status == 'completed';

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage:
                user.url.isNotEmpty ? NetworkImage(user.url) : null,
            backgroundColor: Colors.grey[200],
            child:
                user.url.isEmpty
                    ? Text(
                      user.name.isNotEmpty ? user.name[0] : '?',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 12),
          Text(
            user.name.isNotEmpty ? user.name : tr('deleted_user'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isCompleted ? tr('chat_completed') : tr('chat_ongoing'),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              side: BorderSide(
                color: isCompleted ? Colors.black : Colors.grey.shade400,
              ),
              foregroundColor: isCompleted ? Colors.black : Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            icon: Icon(
              isCompleted ? Icons.refresh : Icons.check_circle_outline,
              size: 16,
            ),
            label: Text(
              isCompleted
                  ? tr('action_resume_chat')
                  : tr('action_complete_chat'),
            ),
            onPressed:
                () => _toggleChatRoomStatus(
                  _selectedChatRoom!.id,
                  _selectedChatRoom!.status,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    MessageModel message,
    bool isMe,
    MyUser otherUser,
  ) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundImage:
                    otherUser.url.isNotEmpty
                        ? NetworkImage(otherUser.url)
                        : null,
                backgroundColor: Colors.grey[200],
                child:
                    otherUser.url.isEmpty
                        ? Text(
                          otherUser.name.isNotEmpty ? otherUser.name[0] : '?',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        )
                        : null,
              ),
              const SizedBox(width: 8),
            ],
            Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isMe ? 12 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.content.isNotEmpty)
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                            fontSize: 13,
                          ),
                        ),
                      if (message.imageUrl!.isNotEmpty) ...[
                        if (message.content.isNotEmpty)
                          const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 250),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              message.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('HH:mm').format(message.timestamp.toLocal()),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pickedImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            kIsWeb
                                ? Image.network(
                                  _pickedImage!.path,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                )
                                : Image.file(
                                  File(_pickedImage!.path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => setState(() => _pickedImage = null),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: Colors.grey,
                  size: 26,
                ),
                onPressed: _pickImage,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: tr('enter_message_hint'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _isSending
                  ? const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                  : InkWell(
                    onTap: _sendMessage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailsPanel(MyUser user) {
    // Filter orders matching user by userId
    final userOrders =
        widget.orders.where((o) {
          return o.userId == user.userId;
        }).toList();

    // Sort user orders by order date descending
    userOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

    final totalCount = userOrders.length;
    final sixMonthsCount =
        userOrders.where((o) {
          try {
            final orderDate = DateTime.tryParse(o.orderDate) ?? DateTime.now();
            return DateTime.now().difference(orderDate).inDays <= 180;
          } catch (_) {
            return false;
          }
        }).length;

    final latestOrder = userOrders.isNotEmpty ? userOrders.first : null;
    final latestAddress =
        latestOrder != null
            ? '${latestOrder.deliveryAddress} ${latestOrder.deliveryAddressDetail}'
            : tr('no_shipping_info');

    return Container(
      width: 280,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile overview
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundImage:
                      user.url.isNotEmpty ? NetworkImage(user.url) : null,
                  backgroundColor: Colors.grey[200],
                  child:
                      user.url.isEmpty
                          ? Text(
                            user.name.isNotEmpty ? user.name[0] : '?',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          )
                          : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user.name.isNotEmpty ? user.name : tr('deleted_user'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user.email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                if (user.phoneNumber != null &&
                    user.phoneNumber!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.phoneNumber!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Badge
          if (totalCount > 1) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text(
                    tr('returning_customer_badge'),
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Address Card
          _buildInfoSection(
            title: tr('shipping_info_title'),
            child: Text(
              latestAddress,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 20),

          // Stats Card
          _buildInfoSection(
            title: tr('purchase_stats_title'),
            child: Column(
              children: [
                _buildStatRow(tr('total_purchases_label'), '$totalCount회'),
                const SizedBox(height: 10),
                _buildStatRow(
                  tr('six_month_repurchases_label'),
                  '$sixMonthsCount회',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
