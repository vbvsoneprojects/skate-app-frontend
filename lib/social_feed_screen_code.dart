import 'package:flutter/material.dart';
import 'main.dart' show ApiService, UserData;
import 'package:google_fonts/google_fonts.dart';

// ==========================================
// 📸 SOCIAL FEED SCREEN
// ==========================================

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  List<dynamic> posts = [];
  bool loading = true;
  final ScrollController _scrollController = ScrollController();
  int _currentOffset = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadPosts() async {
    setState(() => loading = true);
    var data = await ApiService.getFeedPosts(offset: 0, limit: _limit);
    if (mounted) {
      setState(() {
        posts = data;
        _currentOffset = data.length;
        loading = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    var data = await ApiService.getFeedPosts(offset: _currentOffset, limit: _limit);
    if (mounted && data.isNotEmpty) {
      setState(() {
        posts.addAll(data);
        _currentOffset += data.length;
      });
    }
  }

  void _showCreatePostDialog() {
    final _textCtrl = TextEditingController();
    String _tipo = 'general';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Nueva Publicación', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  controller: _textCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: '¿Qué está pasando?',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(15),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _tipo,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF0A0A0A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('General')),
                  DropdownMenuItem(value: 'spot', child: Text('Spot')),
                  DropdownMenuItem(value: 'news', child: Text('Noticia')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => _tipo = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (_textCtrl.text.isEmpty) return;
                
                final success = await ApiService.createPost(
                  UserData.id,
                  _textCtrl.text,
                  '', // imagen vacía por ahora
                  _tipo,
                );
                
                if (mounted) {
                  Navigator.pop(ctx);
                  if (success) {
                    _loadPosts(); // Recargar feed
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Post publicado'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text(
          'FEED SOCIAL',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPosts,
          ),
        ],
      ),
      body: loading && posts.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
            )
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadPosts,
                    color: const Color(0xFFFF6B35),
                    child: posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 80,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No hay publicaciones aún',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '¡Sé el primero en publicar!',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        return _PostCard(
                          post: posts[index],
                          onLike: () async {
                            final result = await ApiService.toggleLike(
                              posts[index]['id_post'],
                              UserData.id,
                            );
                            if (result != null && mounted) {
                              setState(() {
                                posts[index]['likes_count'] = result['likes_count'];
                              });
                            }
                          },
                          onComment: () {
                            _showCommentDialog(posts[index]);
                          },
                          onDelete: () async {
                             bool confirm = await showDialog(
                              context: context,
                              builder: (btx) => AlertDialog(
                                backgroundColor: Colors.black,
                                title: const Text('¿Eliminar publicación?', style: TextStyle(color: Colors.white)),
                                content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(onPressed: ()=>Navigator.pop(btx, false), child: const Text('Cancelar')),
                                  TextButton(onPressed: ()=>Navigator.pop(btx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ) ?? false;

                            if (confirm) {
                              final success = await ApiService.deletePost(posts[index]['id_post'], UserData.id);
                              if (success && mounted) {
                                setState(() {
                                  posts.removeAt(index);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('🗑️ Publicación eliminada'), backgroundColor: Colors.redAccent),
                                );
                              } else if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('❌ Error al eliminar. ¿Tienes permiso?'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostDialog,
        backgroundColor: const Color(0xFFFF6B35),
        icon: const Icon(Icons.add),
        label: const Text('PUBLICAR'),
      ),
    );
  }

  void _showCommentDialog(Map<String, dynamic> post) {
    final _commentCtrl = TextEditingController();
    List<dynamic> comments = [];
    bool loadingComments = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Cargar comentarios al abrir
          if (loadingComments) {
            ApiService.getPostComments(post['id_post']).then((data) {
              if (context.mounted) {
                setDialogState(() {
                  comments = data;
                  loadingComments = false;
                });
              }
            });
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Comentarios', style: TextStyle(color: Colors.white)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // LISTA DE COMENTARIOS
                  Flexible(
                    child: loadingComments
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
                        : comments.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('Sé el primero en comentar', style: TextStyle(color: Colors.white38)),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: comments.length,
                                itemBuilder: (context, index) {
                                  final c = comments[index];
                                  final bool canDelete = c['id_usuario'] == UserData.id || UserData.isAdmin;
                                  
                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Colors.white10)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 15,
                                          backgroundImage: NetworkImage(c['usuario_avatar'] ?? ''),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c['usuario_nombre'] ?? 'Usuario',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                c['texto'],
                                                style: const TextStyle(color: Colors.white70),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // DELETE BUTTON - SIEMPRE VISIBLE CON ETIQUETA
                                        TextButton.icon(
                                          icon: Icon(
                                            Icons.delete_forever, 
                                            color: canDelete ? Colors.redAccent : Colors.grey.withOpacity(0.5), 
                                            size: 20
                                          ),
                                          label: Text(
                                            canDelete ? "BORRAR" : "", 
                                            style: TextStyle(
                                              color: canDelete ? Colors.redAccent : Colors.transparent, 
                                              fontSize: 10, 
                                              fontWeight: FontWeight.bold
                                            )
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () async {
                                            if (!canDelete) return; // Solo accionable si es admin/dueño
                                            
                                            bool confirm = await showDialog(
                                              context: context,
                                              builder: (btx) => AlertDialog(
                                                backgroundColor: Colors.black,
                                                title: const Text('¿Eliminar comentario?', style: TextStyle(color: Colors.white)),
                                                actions: [
                                                  TextButton(onPressed: ()=>Navigator.pop(btx, false), child: const Text('Cancelar')),
                                                  TextButton(onPressed: ()=>Navigator.pop(btx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                                                ],
                                              ),
                                            ) ?? false;
                                            
                                            if (confirm) {
                                              final success = await ApiService.deletePostComment(c['id_comment'], UserData.id);
                                              if (success) {
                                                setDialogState(() {
                                                  comments.removeAt(index);
                                                  post['comments_count'] = (post['comments_count'] ?? 1) - 1;
                                                });
                                                if (mounted) setState(() {});
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                  const Divider(color: Colors.white10),
                  // INPUT NUEVO COMENTARIO
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Escribe algo...',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFFFF6B35)),
                        onPressed: () async {
                          if (_commentCtrl.text.isEmpty) return;
                          
                          final success = await ApiService.addPostComment(
                            post['id_post'],
                            UserData.id,
                            _commentCtrl.text,
                          );
                          
                          if (success) {
                            _commentCtrl.clear();
                            // Recargar comentarios
                            setDialogState(() => loadingComments = true);
                            if (mounted) {
                              setState(() {
                                post['comments_count'] = (post['comments_count'] ?? 0) + 1;
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 📸 POST CARD WIDGET (Instagram-style)
// ==========================================

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback? onDelete; // Callback para eliminar

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComment,
    this.onDelete,
  });

  String _getTimeAgo(String? dateStr) {
    if (dateStr == null) return 'Ahora';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'Ahora';
    } catch (e) {
      return 'Ahora';
    }
  }

  String _getTipoBadge(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'spot':
        return '📍 SPOT';
      case 'news':
        return '📰 NOTICIAS';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = post['usuario_avatar'] ?? 'https://images.unsplash.com/photo-1544005313-94ddf0286df2';
    final username = post['usuario_nombre'] ?? 'Usuario';
    final texto = post['texto'] ?? '';
    final imagen = post['imagen'];
    final likesCount = post['likes_count'] ?? 0;
    final commentsCount = post['comments_count'] ?? 0;
    final fecha = _getTimeAgo(post['fecha_creacion']);
    final tipoBadge = _getTipoBadge(post['tipo']);
    
    // HARDCODED: IDs 1 y 2 son SIEMPRE admin (alvaro y vbvsone)
    final bool isHardcodedAdmin = (UserData.id == 1 || UserData.id == 2);
    final bool canDelete = (post['id_usuario'] == UserData.id) || isHardcodedAdmin;
    
    // DEBUG: Imprimir valores para verificar
    print('🔍 POST DEBUG: user=${UserData.name} id=${UserData.id} isHardcodedAdmin=$isHardcodedAdmin postOwner=${post['id_usuario']} canDelete=$canDelete');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER: Avatar + Username + Time + Delete
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(avatar),
                  backgroundColor: const Color(0xFF0A0A0A),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onLongPress: () {
                          // DEBUG VISIBLE PARA EL USUARIO
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("DEBUG INFO"),
                              content: Text(
                                "Tu Usuario: '${UserData.name}'\n"
                                "ID: ${UserData.id}\n"
                                "Es Admin (BBDD): ${UserData.isAdmin}\n"
                                "Dueño del post: ${post['id_usuario']}\n"
                                "Can Delete: ${canDelete}"
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
                              ],
                            ),
                          );
                        },
                        child: Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        fecha,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tipoBadge.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tipoBadge,
                      style: const TextStyle(
                        color: Color(0xFFFF6B35),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                
                // DELETE BUTTON - SIEMPRE VISIBLE PARA DEBUG
                IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    onPressed: () async {
                      bool confirm = await showDialog(
                        context: context,
                        builder: (btx) => AlertDialog(
                          backgroundColor: Colors.black,
                          title: const Text('¿Eliminar publicación?', style: TextStyle(color: Colors.white)),
                          content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(onPressed: ()=>Navigator.pop(btx, false), child: const Text('Cancelar')),
                            TextButton(onPressed: ()=>Navigator.pop(btx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ) ?? false;

                      if (confirm && onDelete != null) {
                        onDelete!();
                      }
                    },
                  ),
              ],
            ),
          ),

          // TEXTO
          if (texto.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                texto,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),

          // IMAGEN (si existe)
          if (imagen != null && imagen.toString().isNotEmpty)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 400),
              child: Image.network(
                imagen,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: const Color(0xFF0A0A0A),
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.white24, size: 50),
                    ),
                  );
                },
              ),
            ),

          // FOOTER: Likes + Comments
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // LIKE BUTTON
                InkWell(
                  onTap: onLike,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          color: Color(0xFFFF6B35),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          likesCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // COMMENT BUTTON
                InkWell(
                  onTap: onComment,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          commentsCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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
