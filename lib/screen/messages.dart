import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

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
  String? _currentUserId;
  final String _baseUrl = 'http://localhost:8000';

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
        Uri.parse('$_baseUrl/api/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        setState(() {
          _conversations = responseData.map((json) => Conversation.fromJson(json, _baseUrl)).toList();
          _currentUserId = _conversations.isNotEmpty ? _conversations.first.currentUserId : null;
          _isLoading = false;
          _error = null;
        });
      } else {
        throw Exception('Failed to load conversations: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching conversations: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      _showErrorDialog('Erreur', 'Impossible de charger les conversations');
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.bottomSlide,
      title: title,
      desc: message,
      btnOkOnPress: () {},
      btnOkColor: Theme.of(context).colorScheme.primary,
    ).show();
  }

  List<Conversation> get _filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    return _conversations.where((conv) =>
    conv.otherUser?.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false ||
        (conv.lastMessage?.content.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ).animate().fade().scale(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: $_error',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchConversations,
                child: const Text('Réessayer'),
              ).animate().shake(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Messages',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurface),
            onPressed: () => _showNewMessageDialog(context),
          ).animate().fadeIn(delay: 100.ms),
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            onPressed: _fetchConversations,
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchConversations,
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: theme.colorScheme.surface,
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une conversation...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    prefixIcon: Icon(Icons.search,
                        color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear,
                          color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms),
              ),
            ),
            _filteredConversations.isEmpty
                ? SliverFillRemaining(
              child: _buildEmptyState(theme),
            )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final conversation = _filteredConversations[index];
                  return _buildConversationTile(conversation, theme)
                      .animate()
                      .fadeIn(delay: (100 * index).ms)
                      .slideX(begin: 0.2);
                },
                childCount: _filteredConversations.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation, ThemeData theme) {
    final otherUser = conversation.otherUser;
    if (otherUser == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _buildUserAvatar(otherUser, theme),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherUser.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              _formatTimestamp(conversation.updatedAt),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
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
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        onTap: () => _openChatScreen(context, conversation),
      ),
    );
  }

  Widget _buildUserAvatar(User user, ThemeData theme) {
    final avatarUrl = user.isBusiness && user.establishment != null
        ? '$_baseUrl/establishments/${user.establishment!['logoPath']}'
        : user.avatar != null
        ? '$_baseUrl/users/${user.avatar}'
        : null;

    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.2),
                theme.colorScheme.secondary.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: avatarUrl != null
              ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: avatarUrl,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              errorWidget: (context, url, error) => Center(
                child: Text(
                  user.displayName[0].toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              fit: BoxFit.cover,
            ),
          )
              : Center(
            child: Text(
              user.displayName[0].toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        if (user.isBusiness)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
              child: Icon(
                Icons.business,
                size: 8,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ).animate().scale(),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'Aucun message' : 'Aucun résultat trouvé',
            style: TextStyle(
              fontSize: 18,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
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
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ).animate().fadeIn(),
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

  void _openChatScreen(BuildContext context, Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversation: conversation,
          baseUrl: _baseUrl,
          onMessageSent: _fetchConversations,
        ),
      ),
    ).then((_) => _fetchConversations());
  }

  void _showNewMessageDialog(BuildContext context) {
    final theme = Theme.of(context);
    final TextEditingController _userSearchController = TextEditingController();
    List<User> _foundUsers = [];
    bool _isSearching = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              backgroundColor: theme.colorScheme.surface,
              title: Text(
                'Nouveau message',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _userSearchController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un utilisateur ou établissement...',
                        hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.search,
                            color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) async {
                        setState(() => _isSearching = true);
                        try {
                          final users = await _searchUsers(value);
                          if (mounted) {
                            setState(() {
                              _foundUsers = users;
                              _isSearching = false;
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              _foundUsers = [];
                              _isSearching = false;
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _isSearching
                          ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary),
                        ).animate().fade(),
                      )
                          : _foundUsers.isEmpty
                          ? Center(
                        child: Text(
                          'Recherchez un utilisateur pour commencer',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6)),
                        ),
                      )
                          : ListView.builder(
                        itemCount: _foundUsers.length,
                        itemBuilder: (context, index) {
                          final user = _foundUsers[index];
                          return ListTile(
                            leading: _buildUserAvatar(user, theme),
                            title: Text(
                              user.displayName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface),
                            ),
                            subtitle: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(user.email,
                                    style: TextStyle(
                                        color: theme.colorScheme
                                            .onSurface
                                            .withOpacity(0.6))),
                                if (user.isBusiness &&
                                    user.establishment != null)
                                  Text(
                                    'Établissement',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              await _createNewConversation(
                                  context, user);
                            },
                          ).animate().fadeIn(delay: (50 * index).ms);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Annuler',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<User>> _searchUsers(String query) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/api/user/list${query.isNotEmpty ? '?search=$query' : ''}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> _createNewConversation(BuildContext context, User otherUser) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) throw Exception('No token found');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/messages/conversation/${otherUser.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final conversationId = data['conversation_id'].toString();

        await _fetchConversations();

        final newConversation = _conversations.firstWhere(
              (conv) => conv.id == conversationId,
          orElse: () => _conversations.isNotEmpty ? _conversations.first : Conversation.empty(_baseUrl),
        );

        _openChatScreen(context, newConversation);
      } else {
        throw Exception('Failed to create conversation: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating conversation: $e');
      _showErrorDialog('Erreur', 'Impossible de créer la conversation');
    }
  }
}

class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final String baseUrl;
  final VoidCallback onMessageSent;

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.baseUrl,
    required this.onMessageSent,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ScrollController _scrollController = ScrollController();
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
        Uri.parse('${widget.baseUrl}/api/messages/conversation/${widget.conversation.id}'),
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.minScrollExtent);
          }
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
        Uri.parse('${widget.baseUrl}/api/messages/${widget.conversation.id}'),
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
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'Erreur',
        desc: 'Impossible d\'envoyer le message',
        btnOkOnPress: () {},
      ).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(theme),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ).animate().fade(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: _buildAppBar(theme),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: $_error',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchMessages,
                child: const Text('Réessayer'),
              ).animate().shake(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message, theme)
                    .animate()
                    .fadeIn(delay: (50 * index).ms);
              },
            ),
          ),
          _buildMessageInput(theme),
        ],
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme) {
    final otherUser = widget.conversation.otherUser;
    if (otherUser == null) return AppBar(title: Text('Chat', style: TextStyle(color: theme.colorScheme.onSurface)));

    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      elevation: 1,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          _buildUserAvatar(otherUser, theme, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherUser.displayName,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'En ligne',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
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
          icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildUserAvatar(User user, ThemeData theme, {double size = 25}) {
    final avatarUrl = user.isBusiness && user.establishment != null
        ? '${widget.baseUrl}/establishments/${user.establishment!['logoPath']}'
        : user.avatar != null
        ? '${widget.baseUrl}/users/${user.avatar}'
        : null;

    return Stack(
      children: [
        Container(
          width: size * 2,
          height: size * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.2),
                theme.colorScheme.secondary.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: avatarUrl != null
              ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: avatarUrl,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              errorWidget: (context, url, error) => Center(
                child: Text(
                  user.displayName[0].toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: size,
                  ),
                ),
              ),
              fit: BoxFit.cover,
            ),
          )
              : Center(
            child: Text(
              user.displayName[0].toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: size,
              ),
            ),
          ),
        ),
        if (user.isBusiness)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
              child: Icon(
                Icons.business,
                size: size / 2,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBubble(Message message, ThemeData theme) {
    final currentUserId = widget.conversation.currentUserId;
    final isMe = message.sender?.id == currentUserId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 20 : 0),
            topRight: Radius.circular(isMe ? 0 : 20),
            bottomLeft: const Radius.circular(20),
            bottomRight: const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe && message.sender != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.sender!.displayName,
                  style: TextStyle(
                    color: isMe
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            Text(
              message.content,
              style: TextStyle(
                color: isMe
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(message.createdAt),
              style: TextStyle(
                color: isMe
                    ? theme.colorScheme.onPrimary.withOpacity(0.7)
                    : theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 10,
              ),
              textAlign: TextAlign.end,
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMessageInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Tapez votre message...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant,
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
            backgroundColor: theme.colorScheme.primary,
            child: Icon(
              Icons.send,
              color: theme.colorScheme.onPrimary,
              size: 20,
            ),
          ).animate().fadeIn(),
        ],
      ),
    );
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
  final String baseUrl;

  Conversation({
    required this.id,
    required this.user1,
    required this.user2,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    required this.currentUserId,
    required this.baseUrl,
  });

  factory Conversation.fromJson(Map<String, dynamic> json, String baseUrl) {
    return Conversation(
      id: json['id'].toString(),
      user1: User.fromJson(json['user1']),
      user2: User.fromJson(json['user2']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'])
          : null,
      currentUserId: json['currentUserId'].toString(),
      baseUrl: baseUrl,
    );
  }

  static Conversation empty(String baseUrl) {
    return Conversation(
      id: '',
      user1: User.empty(),
      user2: User.empty(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      currentUserId: '',
      baseUrl: baseUrl,
    );
  }

  User? get otherUser {
    if (currentUserId == user1.id) return user2;
    if (currentUserId == user2.id) return user1;
    return null;
  }
}

class User {
  final String id;
  final String email;
  final List<String> roles;
  final String username;
  final String? avatar;
  final String fname;
  final String lname;
  final Map<String, dynamic>? establishment;

  User({
    required this.id,
    required this.email,
    required this.roles,
    required this.username,
    this.avatar,
    required this.fname,
    required this.lname,
    this.establishment,
  });

  String get fullName => '$fname $lname';

  bool get isBusiness => roles.contains('ROLE_ESTABLISHMENT');

  String get displayName {
    if (isBusiness && establishment != null && establishment!['name'] != null) {
      return establishment!['name'];
    }
    return fullName;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      email: json['email'],
      roles: List<String>.from(json['roles']),
      username: json['username'],
      avatar: json['avatar'],
      fname: json['fname'],
      lname: json['lname'],
      establishment: json['establishment'],
    );
  }

  static User empty() {
    return User(
      id: '',
      email: '',
      roles: [],
      username: '',
      fname: '',
      lname: '',
    );
  }
}

class Message {
  final String content;
  final DateTime createdAt;
  final User? sender;
  final String? id;
  final String? conversationId;

  Message({
    required this.content,
    required this.createdAt,
    this.sender,
    this.id,
    this.conversationId,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
      id: json['id']?.toString(),
      conversationId: json['conversationId']?.toString(),
    );
  }
}