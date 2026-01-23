import 'package:flutter/material.dart';
import 'dart:async';
import 'main.dart' show ApiService, UserData;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ==========================================
// 💬 MESSAGES SCREEN (Lista de Conversaciones)
// ==========================================

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<dynamic> conversations = [];
  bool loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    // Auto-refresh cada 5 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadConversations(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    final data = await ApiService.getUserConversations(UserData.id);
    if (mounted) {
      setState(() {
        conversations = data;
        loading = false;
      });
    }
  }

  String _formatTimestamp(String? dateStr) {
    if (dateStr == null) return '';
    try {
      // Parse la fecha que viene del backend (ya en timezone Chile)
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      
      // Calcular diferencia en días (ignorando la hora)
      final dateOnly = DateTime(date.year, date.month, date.day);
      final nowOnly = DateTime(now.year, now.month, now.day);
      final diff = nowOnly.difference(dateOnly).inDays;
      
      // Si es hoy, mostrar solo hora
      if (diff == 0) {
        return DateFormat('HH:mm').format(date);
      }
      // Si es ayer
      if (diff == 1) {
        return 'Ayer ${DateFormat('HH:mm').format(date)}';
      }
      // Si es esta semana (últimos 7 días)
      if (diff < 7) {
        final dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
        final diaName = dias[date.weekday - 1];
        return '$diaName ${DateFormat('HH:mm').format(date)}';
      }
      // Si es más antiguo, mostrar fecha completa
      return DateFormat('dd/MM/yy HH:mm').format(date);
    } catch (e) {
      print('Error formateando fecha: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MENSAJES',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadConversations(),
          ),
        ],
      ),
      body: loading && conversations.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
            )
          : RefreshIndicator(
              onRefresh: () => _loadConversations(),
              color: const Color(0xFFFF6B35),
              child: conversations.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final convo = conversations[index];
                        return _ConversationTile(
                          avatarUrl: convo['avatar'] ?? 'https://images.unsplash.com/photo-1544005313-94ddf0286df2',
                          name: convo['nickname'] ?? 'Usuario',
                          lastMessage: convo['ultimo_mensaje'] ?? '',
                          timestamp: _formatTimestamp(convo['fecha_ultimo_mensaje']),
                          unreadCount: convo['mensajes_no_leidos'] ?? 0,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  otherUserId: convo['otro_usuario_id'],
                                  otherUserName: convo['nickname'] ?? 'Usuario',
                                  otherUserAvatar: convo['avatar'] ?? '',
                                ),
                              ),
                            );
                            _loadConversations(silent: true);
                          },
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.white24,
          ),
          const SizedBox(height: 20),
          Text(
            'No hay mensajes aún',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Envía un mensaje para empezar',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 💬 CONVERSATION TILE
// ==========================================

class _ConversationTile extends StatelessWidget {
  final String avatarUrl;
  final String name;
  final String lastMessage;
  final String timestamp;
  final int unreadCount;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.avatarUrl,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(avatarUrl),
              backgroundColor: const Color(0xFF0A0A0A),
            ),
            const SizedBox(width: 12),
            // Nombre y último mensaje
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        timestamp,
                        style: TextStyle(
                          color: unreadCount > 0 ? const Color(0xFFFF6B35) : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unreadCount > 0 ? Colors.white70 : Colors.white38,
                            fontSize: 14,
                            fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 💬 CHAT SCREEN (Conversación Individual)
// ==========================================

class ChatScreen extends StatefulWidget {
  final int otherUserId;
  final String otherUserName;
  final String otherUserAvatar;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<dynamic> messages = [];
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markMessagesAsRead();
    // Auto-refresh cada 3 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    final data = await ApiService.getConversation(UserData.id, widget.otherUserId);
    if (mounted) {
      setState(() {
        messages = data;
        loading = false;
      });
      if (!silent) _scrollToBottom();
    }
  }

  Future<void> _markMessagesAsRead() async {
    await ApiService.markMessagesAsRead(UserData.id, widget.otherUserId);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageCtrl.text.trim().isEmpty) return;
    
    final text = _messageCtrl.text.trim();
    _messageCtrl.clear();
    
    final success = await ApiService.sendMessage(
      UserData.id,
      widget.otherUserId,
      text,
    );
    
    if (success) {
      await _loadMessages(silent: true);
      _scrollToBottom();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al enviar mensaje'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatMessageTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      // Parse la fecha que viene del backend (ya en timezone Chile)
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      
      // Calcular diferencia en días
      final dateOnly = DateTime(date.year, date.month, date.day);
      final nowOnly = DateTime(now.year, now.month, now.day);
      final diff = nowOnly.difference(dateOnly).inDays;
      
      // Si es hoy, solo hora
      if (diff == 0) {
        return DateFormat('HH:mm').format(date);
      }
      // Si es ayer o más antiguo, mostrar fecha y hora
      if (diff == 1) {
        return 'Ayer ${DateFormat('HH:mm').format(date)}';
      }
      return DateFormat('dd/MM HH:mm').format(date);
    } catch (e) {
      print('Error formateando hora mensaje: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.otherUserAvatar.isNotEmpty
                  ? NetworkImage(widget.otherUserAvatar)
                  : null,
              backgroundColor: const Color(0xFF0A0A0A),
              child: widget.otherUserAvatar.isEmpty
                  ? const Icon(Icons.person, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherUserName,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Lista de mensajes
          Expanded(
            child: loading && messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  )
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 60,
                              color: Colors.white24,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay mensajes',
                              style: TextStyle(color: Colors.white38, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Envía el primer mensaje',
                              style: TextStyle(color: Colors.white24, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg['id_remitente'] == UserData.id;
                          return _MessageBubble(
                            text: msg['texto'] ?? '',
                            timestamp: _formatMessageTime(msg['fecha_envio']),
                            isMe: isMe,
                          );
                        },
                      ),
          ),
          // Input de mensaje
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: TextField(
                      controller: _messageCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 💬 MESSAGE BUBBLE (Burbuja de Mensaje)
// ==========================================

class _MessageBubble extends StatelessWidget {
  final String text;
  final String timestamp;
  final bool isMe;

  const _MessageBubble({
    required this.text,
    required this.timestamp,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                    )
                  : null,
              color: isMe ? null : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timestamp,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
