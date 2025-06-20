import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String _searchQuery = '';
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String? _error;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    try {
      setState(() => _isRefreshing = true);
      final token = await _storage.read(key: 'auth_token');
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('http://localhost:8000/api/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _conversations = data.map((json) => Conversation.fromJson(json)).toList();
          _isLoading = false;
          _error = null;
        });
      } else {
        throw Exception('Failed to load conversations: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  List<Conversation> get _filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    return _conversations.where((conv) =>
    conv.otherUser.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (conv.lastMessage?.content.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchConversations,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.black),
            onPressed: () => _showNewMessageDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchConversations,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchConversations,
        child: Column(
          children: [
            // Barre de recherche
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Rechercher une conversation...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
              ),
            ),

            // Liste des conversations
            Expanded(
              child: _filteredConversations.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                itemCount: _filteredConversations.length,
                itemBuilder: (context, index) {
                  final conversation = _filteredConversations[index];
                  return _buildConversationTile(conversation);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    final otherUser = conversation.otherUser;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: _getAvatarColor(otherUser.id).withOpacity(0.2),
              child: Text(
                otherUser.fullName[0].toUpperCase(),
                style: TextStyle(
                  color: _getAvatarColor(otherUser.id),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            if (otherUser.isBusiness)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.business,
                    size: 8,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherUser.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              _formatTimestamp(conversation.updatedAt),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            conversation.lastMessage?.content ?? 'Aucun message',
            style: TextStyle(
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        onTap: () => _openChatScreen(context, conversation),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'Aucun message'
                : 'Aucun résultat trouvé',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Vos conversations apparaîtront ici'
                : 'Essayez avec d\'autres mots-clés',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}min';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}j';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  Color _getAvatarColor(String userId) {
    final colors = [
      Colors.pink,
      Colors.orange,
      Colors.blue,
      Colors.brown,
      Colors.purple,
      Colors.green,
      Colors.red,
      Colors.amber,
      Colors.cyan,
      Colors.indigo,
    ];
    final index = userId.hashCode % colors.length;
    return colors[index];
  }

  void _openChatScreen(BuildContext context, Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversation: conversation,
          onMessageSent: _fetchConversations,
        ),
      ),
    ).then((_) => _fetchConversations());
  }

  void _showNewMessageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau message'),
        content: const Text('Fonctionnalité à implémenter'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final VoidCallback onMessageSent;

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.onMessageSent,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<Message> _messages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse('http://localhost:8000/api/messages/conversation/${widget.conversation.id}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _messages = (data['messages'] as List)
              .map((json) => Message.fromJson(json))
              .toList();
          _isLoading = false;
          _error = null;
        });
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return;

      final response = await http.post(
        Uri.parse('http://localhost:8000/api/messages/${widget.conversation.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'content': _messageController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        _messageController.clear();
        _fetchMessages();
        widget.onMessageSent();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchMessages,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final otherUser = widget.conversation.otherUser;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _getAvatarColor(otherUser.id).withOpacity(0.2),
            child: Text(
              otherUser.fullName[0].toUpperCase(),
              style: TextStyle(
                color: _getAvatarColor(otherUser.id),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherUser.fullName,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'En ligne',
                  style: TextStyle(
                    color: Colors.green[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.black),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Message message) {
    final currentUserId = widget.conversation.currentUserId;
    final isMe = message.sender.id == currentUserId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Tapez votre message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            mini: true,
            onPressed: _sendMessage,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Color _getAvatarColor(String userId) {
    final colors = [
      Colors.pink,
      Colors.orange,
      Colors.blue,
      Colors.brown,
      Colors.purple,
      Colors.green,
    ];
    final index = userId.hashCode % colors.length;
    return colors[index];
  }
}

class Conversation {
  final String id;
  final User user1;
  final User user2;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Message? lastMessage;
  final String currentUserId;

  Conversation({
    required this.id,
    required this.user1,
    required this.user2,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    required this.currentUserId,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final currentUserId = json['currentUserId']?.toString() ?? '';
    return Conversation(
      id: json['id'].toString(),
      user1: User.fromJson(json['user1']),
      user2: User.fromJson(json['user2']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'])
          : null,
      currentUserId: currentUserId,
    );
  }

  User get otherUser => user1.id == currentUserId ? user2 : user1;
}

class User {
  final String id;
  final String email;
  final List<String> roles;
  final String username;
  final String? avatar;
  final String fname;
  final String lname;

  User({
    required this.id,
    required this.email,
    required this.roles,
    required this.username,
    this.avatar,
    required this.fname,
    required this.lname,
  });

  String get fullName => '$fname $lname';

  bool get isBusiness => roles.contains('ROLE_ESTABLISHMENT');

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      email: json['email'],
      roles: List<String>.from(json['roles']),
      username: json['username'],
      avatar: json['avatar'],
      fname: json['fname'],
      lname: json['lname'],
    );
  }
}

class Message {
  final String id;
  final String content;
  final DateTime createdAt;
  final User sender;
  final Conversation conversation;

  Message({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.sender,
    required this.conversation,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      sender: User.fromJson(json['sender']),
      conversation: Conversation.fromJson(json['conversation']),
    );
  }
}