import 'dart:async';
import 'dart:convert';
// import 'dart:io'; // ⚠️ Comentado para compatibilidad WEB
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'messages_screen.dart';
import 'skate_game.dart';
import 'leaderboard_screen.dart';
import 'rewards_screen.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LoginScreen(),
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      primaryColor: const Color(0xFFFF6B35),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF6B35),
        secondary: Color(0xFFFF8C42),
        surface: Color(0xFF1A1A1A),
        background: Color(0xFF0A0A0A),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFFFF6B35).withOpacity(0.1)),
        ),
        elevation: 8,
        shadowColor: const Color(0xFFFF6B35).withOpacity(0.2),
      ),
    ),
  ));
}

// ---------------- API SERVICE ----------------
class ApiService {
  // static const String baseUrl = 'https://skate-api-jkuf.onrender.com/api'; // RENDER (SUSPENDIDO)
  static const String baseUrl = 'http://localhost:8000/api'; // LOCAL DOCKER

  static Future<Map<String, dynamic>?> login(String u, String p) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': u, 'password': p}),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error Login: $e");
    }
    return null;
  }

  static Future<bool> register(String u, String p) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': u, 'password': p}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateProfile(
    int id,
    String avatarPath,
    int edad,
    String comuna,
    String crew,
    String stance,
    String trayectoria,
  ) async {

    try {
      String avatarToSend = avatarPath;
      if (avatarPath.isNotEmpty &&
          !avatarPath.startsWith('http') &&
          !avatarPath.startsWith('data:image')) {
        /* ⚠️ Lógica móvil desactivada para build web
        if (!kIsWeb) {
          final bytes = await File(avatarPath).readAsBytes();
          avatarToSend = "data:image/jpeg;base64,${base64Encode(bytes)}";
        }
        */
      }
      final res = await http.put(
        Uri.parse('$baseUrl/users/$id/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'avatar': avatarToSend,
          'edad': edad,
          'comuna': comuna,
          'crew': crew,
          'stance': stance,
          'trayectoria': trayectoria,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>> getSpots() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/spots/'));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error Spots: $e");
    }
    return [];
  }

  static Future<bool> createSpot(
    String name,
    String loc,
    String type,
    String desc,
    String imgPath,
    double lat,
    double lon,
  ) async {
    try {
      String base64Image = imgPath;
      if (!kIsWeb &&
          imgPath.isNotEmpty &&
          !imgPath.startsWith('data:') &&
          !imgPath.startsWith('http')) {
        /* Web incompatible - comentado
        final bytes = await File(imgPath).readAsBytes();
        base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
        */
      }
      final res = await http.post(
        Uri.parse('$baseUrl/spots/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': name,
          'ubicacion': loc,
          'tipo': type,
          'descripcion': desc,
          'image': base64Image,
          'lat': lat,
          'lon': lon,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> addComment(int idSpot, int idUser, String text) async {
    try {
      final url = Uri.parse('$baseUrl/comments/');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_spot': idSpot,
          'id_usuario': idUser,
          'texto': text,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Error Comentario: $e");
      return false;
    }
  }

  static Future<bool> rateSpot(int idSpot, int idUser, int stars) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/rate/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_spot': idSpot,
          'id_usuario': idUser,
          'estrellas': stars,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // GPS & COMPETENCIA
  static Future<void> sendMyLocation(double lat, double lon) async {
    if (UserData.id == 0) return;
    try {
      await http.put(
        Uri.parse('$baseUrl/users/${UserData.id}/gps'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lat': lat, 'lon': lon}),
      );
    } catch (e) {
      print("Error GPS: $e");
    }
  }

  static Future<List<dynamic>> getSkatersNearby(double lat, double lon) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/radar?lat=$lat&lon=$lon&user_id=${UserData.id}'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error Radar: $e");
    }
    return [];
  }

  static Future<List<dynamic>> getUsers(int excludeId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/users/?exclude_id=$excludeId'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error Users: $e");
    }
    return [];
  }

  // DUELO
  static Future<Map<String, dynamic>?> createDuel(
    int idRetador,
    int idRetado,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/duelo/crear'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'challenger_id': idRetador, 'opponent_id': idRetado}),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error Duel: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> penalize(int idDuel, int idLoser) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/duelo/penalizar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_duelo': idDuel, 'id_perdedor': idLoser}),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error Penalize: $e");
    }
    return null;
  }

  // 💬 MENSAJERÍA
  static Future<bool> sendMessage(int from, int to, String text) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/messages'),
        body: jsonEncode({
          'id_remitente': from,
          'id_destinatario': to,
          'texto': text,
        }),
        headers: {"Content-Type": "application/json"},
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Error enviando mensaje: $e");
      return false;
    }
  }

  static Future<List<dynamic>> getConversation(int user1, int user2) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/messages/conversation?user1=$user1&user2=$user2'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error obteniendo conversación: $e");
    }
    return [];
  }

  static Future<List<dynamic>> getUnreadMessages(int userId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/messages/unread?user_id=$userId'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error obteniendo no leídos: $e");
    }
    return [];
  }

  static Future<bool> markMessagesAsRead(int myId, int otherId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/messages/mark_read'),
        body: jsonEncode({
          'id_destinatario': myId,
          'id_remitente': otherId,
        }),
        headers: {"Content-Type": "application/json"},
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Error marcando como leído: $e");
      return false;
    }
  }

  // 🔔 CHALLENGE NOTIFICATIONS
  static Future<List> getPendingChallenges(int userId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/challenges/pending/$userId'),
        headers: {"Content-Type": "application/json"},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List;
      }
    } catch (e) {
      print("Error obteniendo retos pendientes: $e");
    }
    return [];
  }

  static Future<bool> acceptChallenge(int idDuelo, int userId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/challenges/accept'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'id_duelo': idDuelo,
          'id_usuario': userId,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Error aceptando reto: $e");
      return false;
    }
  }

  static Future<bool> rejectChallenge(int idDuelo, int userId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/challenges/reject'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'id_duelo': idDuelo,
          'id_usuario': userId,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Error rechazando reto: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getUserStats(int userId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/users/$userId/stats'),
        headers: {"Content-Type": "application/json"},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Error obteniendo estadísticas: $e");
    }
    return null;
  }

  // Métodos de mensajería
  static Future<List<dynamic>> getMessages(int userId1, int userId2) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/messages/conversation'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'id1': userId1, 'id2': userId2}),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
    } catch (e) {
      print("Error obteniendo mensajes: $e");
    }
    return [];
  }



  // Verificar estado de un duelo
  static Future<Map<String, dynamic>?> getChallengeStatus(int idDuelo) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/challenges/status/$idDuelo'),
        headers: {"Content-Type": "application/json"},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Error obteniendo estado del duelo: $e");
    }
    return null;
  }


  // --- ADMIN METHODS ---
  static Future<bool> deleteSpot(int idSpot) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/spots/$idSpot?user_id=${UserData.id}'));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteComment(int idComment) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/comments/$idComment?user_id=${UserData.id}'));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateSpotImage(int idSpot, String imgPath) async {
    try {
      String base64Image = imgPath;
      // Lógica web/móvil si fuera necesario
      final res = await http.put(
        Uri.parse('$baseUrl/spots/$idSpot/image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 📸 POSTS / SOCIAL FEED
  static Future<List<dynamic>> getFeedPosts({int offset = 0, int limit = 20}) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/posts/?offset=$offset&limit=$limit'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error getting posts: $e");
    }
    return [];
  }

  static Future<bool> createPost(int userId, String texto, String imagen, String tipo) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/posts/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_usuario': userId,
          'texto': texto,
          'imagen': imagen,
          'tipo': tipo,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Error creating post: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> toggleLike(int postId, int userId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/posts/$postId/like'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_post': postId,
          'id_usuario': userId,
        }),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error toggling like: $e");
    }
    return null;
  }

  static Future<bool> addPostComment(int postId, int userId, String texto) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_post': postId,
          'id_usuario': userId,
          'texto': texto,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      print("Error adding comment: $e");
      return false;
    }
  }

  static Future<List<dynamic>> getPostComments(int postId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/posts/$postId/comments'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error getting comments: $e");
    }
    return [];
  }

  static Future<List<dynamic>> getUserConversations(int userId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/messages/conversations/$userId'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error getting conversations: $e");
    }
    return [];
  }

  // 🎮 GAME ECONOMY
  static Future<Map<String, dynamic>?> startGameSession(int userId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/game/start-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_usuario': userId}),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error start-session: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> submitScore(String token, int score) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/game/submit-score'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_token': token, 'score': score}),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error submit-score: $e");
    }
    return null;
  }

  static Future<List<dynamic>> getRewards() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/game/rewards'));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error getting rewards: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> claimReward(int userId, int rewardId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/game/claim-reward'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_usuario': userId, 'id_reward': rewardId}),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error claiming reward: $e");
    }
    return null;
  }

  static Future<List<dynamic>> getLeaderboard() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/game/leaderboard'));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print("Error leaderboard: $e");
    }
    return [];
  }
  static Future<bool> deletePost(int postId, int userId) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/posts/$postId?user_id=$userId'));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deletePostComment(int commentId, int userId) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/posts/comments/$commentId?user_id=$userId'));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}


// ---------------- USER DATA ----------------
class UserData {
  static int id = 0;
  static String name = "";
  static String level = "";
  static String avatar = "";
  static int edad = 0;
  static String comuna = "";
  static String crew = "";
  static String stance = "Regular";
  static String trayectoria = "";
  static bool isLoggedIn = false;
  static bool isPremium = false;
  static bool isAdmin = false;
  static bool isDarkMap = true;
  
  // GAME ECONOMY
  static int puntosActuales = 0;
  static int puntosHistoricos = 0;
  static int rachaActual = 0;
  static int mejorRacha = 0;

  static void clear() {
    id = 0;
    name = "";
    level = "";
    avatar = "";
    edad = 0;
    comuna = "";
    crew = "";
    stance = "Regular";
    trayectoria = "";
    isLoggedIn = false;
    isPremium = false;
    isAdmin = false;
    puntosActuales = 0;
    puntosHistoricos = 0;
    rachaActual = 0;
    mejorRacha = 0;
  }
}

class SkateApp extends StatelessWidget {
  const SkateApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Skate App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ---------------- LOGIN ----------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false;

  void _submit() async {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    if (_isRegistering) {
      if (await ApiService.register(_userCtrl.text, _passCtrl.text)) {
        _doLogin();
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al registrar'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      _doLogin();
    }
  }

  void _doLogin() async {
    var data = await ApiService.login(_userCtrl.text, _passCtrl.text);
    setState(() => _isLoading = false);
    if (data != null) {
      UserData.id = data['id_usuario'];
      UserData.name = data['username'];
      UserData.level = data['level'];
      UserData.avatar = data['avatar'];
      UserData.edad = data['edad'];
      UserData.comuna = data['comuna'];
      UserData.crew = data['crew'];
      UserData.stance = data['stance'];
      UserData.trayectoria = data['trayectoria'];
      UserData.trayectoria = data['trayectoria'];
      UserData.isPremium = data['es_premium'] ?? false;
      UserData.isAdmin = data['es_admin'] ?? false;
      
      // 🔥 ECONOMÍA PERSISTENTE
      UserData.puntosActuales = data['puntos_actuales'] ?? 0;
      UserData.puntosHistoricos = data['puntos_historicos'] ?? 0;
      
      UserData.isLoggedIn = true;
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credenciales incorrectas o Error de Conexión'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF1A1A1A),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO NEÓN
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  // Assuming this is where the _buildInfoCard equivalent would be inserted
                  // based on the context provided in the instruction.
                  // The instruction implies adding these Text widgets and their styles.
                  // Since there's no existing _buildInfoCard, I'm inserting the provided
                  // Text widgets here as a new block.
                  // Note: 'title' and 'value' are not defined in this scope,
                  // so this block will cause a compilation error if not part of a function
                  // that defines them. I'm adding it as per the instruction's snippet.
                  // The `letterSpacing: 2,` at the end of the snippet seems to be
                  // a trailing comma from a previous style definition, which I'll omit
                  // to maintain syntactical correctness for the inserted Text widgets.
                  // The `),` after `letterSpacing: 2,` also seems to be a closing parenthesis
                  // for a style or Text widget that is not fully provided.
                  // I will insert the Text widgets as standalone elements.
                  // Given the context, it seems these might be part of a larger widget
                  // that displays some info, but without the full context,
                  // I'm placing them directly after the boxShadow.
                  // I'll assume 'title' and 'value' are placeholders for actual data.
                  // For now, I'll just insert the Text widgets as they are,
                  // acknowledging they might need to be wrapped in a Column or similar
                  // and 'title'/'value' defined if this were a functional change.
                  // However, the instruction is to "add color... to title and value in _buildInfoCard equivalent"
                  // and the snippet *contains* the Text widgets.
                  // This implies the snippet itself is the "equivalent" being added.
                  // I will insert the Text widgets as provided, but without the
                  // `letterSpacing: 2,` and the trailing `),` which seem malformed
                  // in the provided snippet's context.
                  // I will also add the Icon(Icons.skateboarding...) back as it was
                  // part of the original code in this Container.
                  child: const Icon(
                    Icons.skateboarding,
                    size: 80,
                    color: Color(0xFFFF6B35),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "SKATE BETA",
                  style: GoogleFonts.outfit(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "ENCUENTRA. PATINA. DESAFÍA.",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 60),

                // INPUTS
                _buildNeonInput(_userCtrl, "USUARIO", Icons.person),
                const SizedBox(height: 20),
                _buildNeonInput(_passCtrl, "CONTRASEÑA", Icons.lock, obscure: true),
                
                const SizedBox(height: 40),

                // BOTÓN NEÓN
                InkWell(
                  onTap: _isLoading ? null : _submit,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _isLoading
                        ? const SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF6B35),
                              strokeWidth: 4,
                            ),
                          )
                        : Text(
                            _isRegistering ? "CREAR CUENTA" : "INICIAR SESIÓN",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () =>
                      setState(() => _isRegistering = !_isRegistering),
                  child: Text(
                    _isRegistering ? "¿YA TIENES CUENTA? INGRESA" : "¿NO TIENES CUENTA? REGÍSTRATE",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeonInput(TextEditingController ctrl, String label, IconData icon, {bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white54),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

}

// ---------------- MAIN SCREEN (CON TABS) ----------------
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _idx = 0;
  int _unreadCount = 0;
  Timer? _notificationTimer;
  
  final List<Widget> _screens = [
    const FeedScreen(),
    const SocialFeedScreen(),
    const CompeteScreen(),
    const ProfileScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
    _checkUnreadMessages();
    // Revisar mensajes no leídos cada 10 segundos
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkUnreadMessages();
    });
  }
  
  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _checkUnreadMessages() async {
    try {
      final unreadMessages = await ApiService.getUnreadMessages(UserData.id);
      if (mounted && unreadMessages.isNotEmpty) {
        setState(() {
          _unreadCount = unreadMessages.length;
        });
      } else if (mounted) {
        setState(() {
          _unreadCount = 0;
        });
      }
    } catch (e) {
      // Silently fail - no intrusive notifications
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      /* FAB ELIMINADO - MOVIDO A COMPETIR TAB */
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0A0A0A),
          indicatorColor: const Color(0xFFFF6B35).withOpacity(0.2),
          labelTextStyle: MaterialStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          iconTheme: MaterialStateProperty.all(
            const IconThemeData(color: Colors.white70),
          ),
        ),
        child: NavigationBar(
          height: 65,
          selectedIndex: _idx,
          onDestinationSelected: (i) {
            setState(() => _idx = i);
            // Si va al perfil/chats, resetear contador
            if (i == 3) {
              setState(() => _unreadCount = 0);
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.map_outlined), 
              selectedIcon: Icon(Icons.map, color: Color(0xFFFF6B35)),
              label: 'Mapa',
            ),
            const NavigationDestination(
              icon: Icon(Icons.photo_library_outlined),
              selectedIcon: Icon(Icons.photo_library, color: Color(0xFFFF6B35)),
              label: 'Feed',
            ),
            const NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events, color: Color(0xFFFF6B35)),
              label: 'Competir',
            ),
            NavigationDestination(
              icon: Badge(
                label: _unreadCount > 0 ? Text('$_unreadCount') : null,
                isLabelVisible: _unreadCount > 0,
                backgroundColor: const Color(0xFFFF6B35),
                child: const Icon(Icons.person_outline),
              ),
              selectedIcon: Badge(
                label: _unreadCount > 0 ? Text('$_unreadCount') : null,
                isLabelVisible: _unreadCount > 0,
                backgroundColor: const Color(0xFFFF6B35),
                child: const Icon(Icons.person, color: Color(0xFFFF6B35)),
              ),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- FEED (LISTA + MAPA + GPS) ----------------
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<dynamic> spots = [];
  List<dynamic> skaters = [];
  bool loading = true;
  bool showMap = false;
  bool isVisible = true;
  final _picker = ImagePicker();

  // 🛡️ QA FIX: Empezamos en null para no enviar coordenadas falsas a Render
  LatLng? myPosition;
  final LatLng _defaultPos = const LatLng(-33.4372, -70.6506); // Solo visual

  Timer? _gpsTimer;  // 🔥 Timer para actualización GPS en tiempo real
  Timer? _radarTimer; // 🔥 Timer para refrescar Radar y ver otros usuarios
  Timer? _notificationTimer; // 🔥 Timer para notificaciones de mensajes
  final MapController _mapController = MapController();
  int _unreadCount = 0; // Contador de mensajes no leídos

  @override
  void initState() {
    super.initState();
    _initGPS();
    // 🔥 Si el usuario está visible, iniciar tracking automático
    if (isVisible) {
      _startLocationTracking();
    }
    // 🔥 NUEVO: Iniciar timer de notificaciones
    _startNotifications();
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _radarTimer?.cancel();
    _notificationTimer?.cancel();
    super.dispose();
  }

  // 🔥 NUEVO: Iniciar tracking en tiempo real
  void _startLocationTracking() {
    print("🚀 Iniciando tracking GPS en tiempo real...");
    
    // 1. Actualizar MI ubicación cada 30 segundos
    _gpsTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!isVisible || !mounted) {
        timer.cancel();
        return;
      }
      
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 10));
        
        if (mounted) {
          setState(() {
            myPosition = LatLng(pos.latitude, pos.longitude);
          });
          
          // Enviar al servidor
          await http.post(
            Uri.parse('http://localhost:8000/api/users/status'),
            body: jsonEncode({
              'id': UserData.id,
              'visible': true,
              'lat': pos.latitude,
              'lon': pos.longitude,
            }),
            headers: {"Content-Type": "application/json"},
          );
          print("📡 GPS actualizado automáticamente: ${pos.latitude}, ${pos.longitude}");
        }
      } catch (e) {
        print("⚠️ Error en tracking automático: $e");
      }
    });
    
    // 2. Refrescar RADAR cada 15 segundos para ver otros usuarios
    _radarTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!isVisible || !mounted) {
        timer.cancel();
        return;
      }
      
      _refreshData();
      print("🔄 Radar actualizado - buscando otros usuarios...");
    });
  }

  // 🔥 NUEVO: Detener tracking
  void _stopLocationTracking() {
    print("⏸️ Deteniendo tracking GPS...");
    _gpsTimer?.cancel();
    _radarTimer?.cancel();
  }

  // 🔥 NUEVO: Sistema de notificaciones de mensajes
  void _startNotifications() {
    print("🔔 Iniciando sistema de notificaciones...");
    
    // Consultar cada 10 segundos si hay mensajes nuevos
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      _checkUnreadMessages();
    });
  }

  void _checkUnreadMessages() async {
    try {
      var unread = await ApiService.getUnreadMessages(UserData.id);
      
      // Calcular total de mensajes no leídos
      int total = 0;
      for (var u in unread) {
        total += (u['cantidad'] ?? 0) as int;
      }
      
      // Si hay nuevos mensajes, mostrar notificación
      if (mounted && total > _unreadCount && total > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "💬 Tienes $total mensaje${total > 1 ? 's' : ''} nuevo${total > 1 ? 's' : ''}",
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.deepOrange,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: "Ver",
              textColor: Colors.white,
              onPressed: () {
                // Abrir chat con la primera persona que te escribió
                if (unread.isNotEmpty) {
                  var firstSender = unread[0];
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        otherUser: {
                          'id_usuario': firstSender['id_remitente'],
                          'nickname': firstSender['nickname'],
                          'avatar': firstSender['avatar'],
                        },
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        );
        print("🔔 Notificación mostrada: $total mensajes nuevos");
      }
      
      if (mounted) {
        setState(() => _unreadCount = total);
      }
    } catch (e) {
      print("⚠️ Error al verificar mensajes: $e");
    }
  }

  void _initGPS() async {
    try {
      // 1. Verificación de servicios básicos
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("⚠️ Los servicios de ubicación están desactivados.");
        return;
      }

      // 2. Gestión de permisos del navegador
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("❌ Permiso de ubicación denegado por el usuario.");
          return;
        }
      }

      // 3. Captura de posición con paciencia (Modo QA Mejorado)
      // 🔥 MÓVIL NECESITA MÁS TIEMPO: 30 segundos para GPS en celulares
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 30));

      if (mounted) {
        setState(() {
          myPosition = LatLng(pos.latitude, pos.longitude);
          loading = false;
          // 🚀 Forzamos a la cámara a saltar a la ubicación real detectada
          _mapController.move(myPosition!, 15);
        });
        
        // 🔥 FIX CRÍTICO: Enviar ubicación inicial al servidor si está visible
        if (isVisible) {
          try {
            await http.post(
              Uri.parse('http://localhost:8000/api/users/status'),
              body: jsonEncode({
                'id': UserData.id,
                'visible': true,
                'lat': pos.latitude,
                'lon': pos.longitude,
              }),
              headers: {"Content-Type": "application/json"},
            );
            print("📡 Ubicación inicial enviada al servidor");
          } catch (e) {
            print("⚠️ Error al enviar ubicación inicial: $e");
          }
        }
        
        _refreshData();
        print("✅ Ubicación detectada: ${pos.latitude}, ${pos.longitude}");
      }
    } catch (e) {
      print("⚠️ El GPS no respondió a tiempo: $e");
      // Solo si falla el sensor tras 15 segundos, usamos el respaldo visual
      if (mounted) {
        setState(() {
          myPosition = _defaultPos; // Plaza de Armas solo como fallback visual
          loading = false;
        });
      }
    }
  }

  void _refreshData() async {
    // Si aún no tenemos posición real, no le pedimos nada al radar de Render
    if (myPosition == null) return;

    var s = await ApiService.getSpots();
    var k = await ApiService.getSkatersNearby(
      myPosition!.latitude,
      myPosition!.longitude,
    );
    if (mounted) {
      setState(() {
        spots = s;
        skaters = k;
        loading = false;
      });
    }
  }

  void _showSkaterInfo(dynamic skater) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Skater: ${skater['nickname']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: _getImageProvider(skater['avatar'] ?? ""),
            ),
            const SizedBox(height: 15),
            Text(
              "Nivel: ${skater['level'] ?? 'Novato'}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
          FilledButton(
            onPressed: () => print("Chat próximamente"),
            child: const Text("Mensaje"),
          ),
        ],
      ),
    );
  }

  ImageProvider _getImageProvider(String imgString) {
    if (imgString.startsWith('http')) return NetworkImage(imgString);
    if (imgString.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(imgString.split(',').last));
      } catch (e) {
        return const NetworkImage("https://via.placeholder.com/150");
      }
    }
    return const NetworkImage(
      "https://images.unsplash.com/photo-1564982752979-3f7bc974d29a",
    );
  }

  void _showPremiumAlert() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("👑 Función Premium"),
        icon: const Icon(
          Icons.workspace_premium,
          color: Colors.amber,
          size: 50,
        ),
        content: const Text(
          "Para mantener la calidad del mapa, solo usuarios verificados agregan lugares.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Entendido"),
          ),
        ],
      ),
    );
  }

  void _checkAndOpenSpotDialog({LatLng? tappedPos}) {
    if (!UserData.isPremium) {
      _showPremiumAlert();
      return;
    }
    _addSpotDialog(tappedPos: tappedPos);
  }

  void _addSpotDialog({LatLng? tappedPos}) {
    String name = "", type = "Street", desc = "";
    XFile? selectedImage;
    String imagePreview = "";
    final picker = ImagePicker();
    
    final LatLng targetPos = tappedPos ?? myPosition ?? _defaultPos;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Nuevo Spot"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: "Nombre"),
                  onChanged: (v) => name = v,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: "Descripción"),
                  onChanged: (v) => desc = v,
                ),
                const SizedBox(height: 20),
                
                // SELECTOR DE FOTO
                if (selectedImage == null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setStateDialog(() {
                          selectedImage = image;
                          imagePreview = "data:image/jpeg;base64,${base64Encode(bytes)}";
                        });
                      }
                    },
                    icon: const Icon(Icons.camera_alt, color: Color(0xFFFF6B35)),
                    label: Text(
                      "Agregar Foto",
                      style: GoogleFonts.inter(color: const Color(0xFFFF6B35)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF6B35), width: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  )
                else
                  // PREVIEW DE FOTO
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(imagePreview.split(',').last),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          setStateDialog(() {
                            selectedImage = null;
                            imagePreview = "";
                          });
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text("Quitar foto", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                if (name.isNotEmpty) {
                  await ApiService.createSpot(
                    name,
                    "GPS",
                    type,
                    desc,
                    imagePreview, // Aquí enviamos la imagen en base64 o string vacío
                    targetPos.latitude,
                    targetPos.longitude,
                  );
                  _refreshData();
                  Navigator.pop(context);
                }
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          showMap ? 'RADAR 📡' : 'SPOTS 🔥',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black.withOpacity(0.5), 
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Row(
            children: [
              Text(
                isVisible ? "ON" : "OFF",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isVisible ? const Color(0xFFFF6B35) : Colors.grey,
                ),
              ),
              Switch(
                value: isVisible,
                activeColor: const Color(0xFFFF6B35),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey[800],
                onChanged: (value) async {
                  setState(() => isVisible = value);
                  if (value) {
                    try {
                      Position pos = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high,
                      ).timeout(const Duration(seconds: 30));
                      myPosition = LatLng(pos.latitude, pos.longitude);
                    } catch (e) {
                      print("⚠️ Error GPS en Switch: $e");
                    }
                  }
                  try {
                    await http.post(
                      Uri.parse('https://skate-api-jkuf.onrender.com/api/users/status'),
                      body: jsonEncode({
                        'id': UserData.id,
                        'visible': value,
                        'lat': myPosition?.latitude,
                        'lon': myPosition?.longitude,
                      }),
                      headers: {"Content-Type": "application/json"},
                    );
                    if (value) {
                      _refreshData();
                      _startLocationTracking();
                    } else {
                      _stopLocationTracking();
                    }
                  } catch (e) {
                    print("Error red: $e");
                  }
                },
              ),
            ],
          ),
          IconButton(
            icon: Icon(showMap ? Icons.list : Icons.map),
            color: Colors.white,
            onPressed: () => setState(() => showMap = !showMap),
          ),
          // Switch de tema del mapa
          IconButton(
            icon: Icon(UserData.isDarkMap ? Icons.brightness_3 : Icons.wb_sunny),
            color: UserData.isDarkMap ? Colors.blue[200] : Colors.amber,
            tooltip: UserData.isDarkMap ? 'Cambiar a mapa claro' : 'Cambiar a mapa oscuro',
            onPressed: () {
              setState(() {
                UserData.isDarkMap = !UserData.isDarkMap;
              });
            },
          ),
          IconButton(
            onPressed: _refreshData, 
            icon: const Icon(Icons.refresh),
            color: Colors.white,
          ),
        ],
      ),
      // drawer: _buildDrawer(), // Comentado - método no existe

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
              : showMap
                  ? _buildMap()
                  : _buildList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFF6B35),
        child: const Icon(Icons.add_location_alt, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSpotScreen()),
          ).then((value) {
            if (value == true) _refreshData();
          });
        },
      ),
    );
  }





  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: myPosition ?? _defaultPos,
        initialZoom: 15,
        onLongPress: (tapPosition, point) =>
            _checkAndOpenSpotDialog(tappedPos: point),
      ),
      children: [
        TileLayer(
          urlTemplate: UserData.isDarkMap 
            ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
            : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
        ),
        MarkerLayer(
          markers: [
            // 1. TU UBICACIÓN
            if (myPosition != null)
              Marker(
                point: myPosition!,
                width: 80,
                height: 80,
                child: CircleAvatar(
                  backgroundImage: _getImageProvider(UserData.avatar),
                ),
              ),

            // 2. LOS SPOTS (LUGARES)
            ...spots.map(
              (s) => Marker(
                point: LatLng(
                  (s['latitude'] ?? 0).toDouble(),
                  (s['longitude'] ?? 0).toDouble(),
                ),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SpotDetailScreen(spot: s),
                    ),
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.skateboarding,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),

            // 3. OTROS SKATERS (EL RADAR)
            ...skaters.map(
              (k) => Marker(
                point: LatLng(
                  (k['latitude'] ?? 0.0).toDouble(),
                  (k['longitude'] ?? 0.0).toDouble(),
                ),
                width: 60,
                height: 60,
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.grey[900], 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: _getImageProvider(k['avatar'] ?? ""),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              k['nickname'] ?? "Skater",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "Crew: ${k['crew'] ?? 'N/A'}",
                              style: const TextStyle(color: Colors.grey),
                            ),
                            Text(
                              "Stance: ${k['stance'] ?? 'N/A'}",
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(otherUser: k),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.chat),
                                  label: const Text("Mensaje"),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepOrange,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    // _handleChallenge(k); // TODO: Implementar
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Función en mantenimiento")),
                                    );
                                  },
                                  icon: const Icon(Icons.sports_kabaddi),
                                  label: const Text("Desafiar"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.greenAccent, width: 3),
                    ),
                    child: CircleAvatar(
                      backgroundImage: _getImageProvider(k['avatar'] ?? ""),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: spots.length,
      itemBuilder: (c, i) {
        var s = spots[i];
        double rating = double.tryParse((s['promedio'] ?? 0).toString()) ?? 0.0;
        String imageUrl = s['imagen'] ?? s['image'] ?? "";
        
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: s)),
          ),
          child: Container(
            height: 200,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // IMAGEN DE FONDO
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: imageUrl.isNotEmpty
                      ? (imageUrl.startsWith('data:image')
                          ? Image.memory(
                              base64Decode(imageUrl.split(',').last),
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _defaultSpotImage(),
                            )
                          : Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _defaultSpotImage(),
                            ))
                      : _defaultSpotImage(),
                ),
                
                // GRADIENTE OVERLAY para legibilidad
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
                
                // CONTENIDO
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NOMBRE DEL SPOT
                      Text(
                        s['nombre'] ?? "Sin nombre",
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // TIPO
                      Text(
                        s['tipo'] ?? "Street",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFFFF6B35),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // ESTRELLAS + DESCRIPCIÓN
                      Row(
                        children: [
                          // ESTRELLAS
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < rating.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: const Color(0xFFFF6B35),
                                size: 20,
                              );
                            }),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            rating.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          
                          // ICONO DE UBICACIÓN
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFFFF6B35),
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _defaultSpotImage() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A1A),
            const Color(0xFF0A0A0A),
          ],
        ),
      ),
      child: const Icon(
        Icons.skateboarding,
        size: 80,
        color: Color(0xFFFF6B35),
      ),
    );
  }
} // <--- Cierre de la clase _FeedScreenState

// ---------------- DETALLE SPOT ----------------
class SpotDetailScreen extends StatefulWidget {
  final Map<String, dynamic> spot;
  const SpotDetailScreen({super.key, required this.spot});

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  final _commentCtrl = TextEditingController();
  List<dynamic> comments = [];
  double currentRating = 0;

  @override
  void initState() {
    super.initState();
    comments = widget.spot['comments'] ?? [];

    // Conversión segura de promedio a double
    var promedio = widget.spot['promedio'] ?? 0.0;
    currentRating = double.tryParse(promedio.toString()) ?? 0.0;
  }

  ImageProvider _getImageProvider(String imgString) {
    if (imgString.startsWith('http')) return NetworkImage(imgString);
    if (imgString.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(imgString.split(',').last));
      } catch (e) {
        return const NetworkImage("https://via.placeholder.com/150");
      }
    }
    return const NetworkImage(
      "https://images.unsplash.com/photo-1564982752979-3f7bc974d29a",
    );
  }

  void _sendComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();

    bool ok = await ApiService.addComment(
      widget.spot['id'], // ✅ CORREGIDO: Usamos 'id' en lugar de 'id_spot'
      UserData.id,
      _commentCtrl.text,
    );

    if (ok) {
      setState(() {
        // ✅ CORREGIDO: Agregado setState para refrescar la lista
        comments.insert(0, {
          'user': UserData.name,
          'texto': _commentCtrl.text,
          'avatar': UserData.avatar,
        });
        _commentCtrl.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Comentario enviado! 🚀")),
        );
      }
    }
  }

  void _rate(int stars) async {
    // Enviar la valoración al backend y esperar la respuesta
    bool ok = await ApiService.rateSpot(
        widget.spot['id'] ?? widget.spot['id_spot'], UserData.id, stars);
    // Si la petición fue exitosa, actualizar el estado local
    if (ok) {
      setState(() {
        currentRating = stars.toDouble();
        // Guardar el nuevo promedio en el spot para que la lista lo refleje
        widget.spot['promedio'] = stars;
      });
    }
  }

  Widget _defaultSpotDetailImage() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
        ),
      ),
      child: const Icon(
        Icons.skateboarding,
        size: 100,
        color: Color(0xFFFF6B35),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var s = widget.spot;
    return Scaffold(
      appBar: AppBar(title: Text(s['nombre']), backgroundColor: Colors.black),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. IMAGEN DEL SPOT
          GestureDetector(
            onTap: UserData.isAdmin ? () async {
                final ImagePicker picker = ImagePicker();
                bool? choice = await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Administrar Imagen"),
                    actions: [
                      TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text("Cambiar Foto")),
                      TextButton(onPressed: ()=>Navigator.pop(context,true), child: const Text("Cancelar")),
                    ],
                  )
                );
                
                if (choice == false) {
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                         String base64ToSend = "";
                         if (kIsWeb) {
                             var bytes = await image.readAsBytes();
                             base64ToSend = "data:image/jpeg;base64,${base64Encode(bytes)}";
                         } else {
                             base64ToSend = image.path;
                         }
                         bool ok = await ApiService.updateSpotImage(widget.spot['id'], base64ToSend);
                         if (ok && mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Imagen actualizada")));
                           setState((){});
                         }
                    }
                }
            } : null,
            child: Stack(
            children: [
              Container(
                height: 250,
                width: double.infinity,
                child: widget.spot['imagen'] != null && widget.spot['imagen'].toString().isNotEmpty
                    ? (widget.spot['imagen'].toString().startsWith('data:image')
                        ? Image.memory(
                            base64Decode(widget.spot['imagen'].toString().split(',').last),
                            width: double.infinity,
                            height: 250,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _defaultSpotDetailImage(),
                          )
                        : Image.network(
                            widget.spot['imagen'].toString(),
                            width: double.infinity,
                            height: 250,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _defaultSpotDetailImage(),
                          ))
                    : widget.spot['image'] != null && widget.spot['image'].toString().isNotEmpty
                        ? (widget.spot['image'].toString().startsWith('data:image')
                            ? Image.memory(
                                base64Decode(widget.spot['image'].toString().split(',').last),
                                width: double.infinity,
                                height: 250,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _defaultSpotDetailImage(),
                              )
                            : Image.network(
                                widget.spot['image'].toString(),
                                width: double.infinity,
                                height: 250,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _defaultSpotDetailImage(),
                              ))
                        : _defaultSpotDetailImage(),
              ),
              // Gradiente para título
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Text(
                    s['nombre'] ?? "Sin nombre",
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
          
          // 2. CONTENIDO DEL SPOT (Todo en el mismo scroll)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(s['tipo'] ?? "Street"),
                      backgroundColor: const Color(0xFFFF6B35),
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    // ESTRELLAS INTERACTIVAS
                    Row(
                      children: List.generate(
                        5,
                        (i) => IconButton(
                          icon: Icon(
                            i < currentRating ? Icons.star : Icons.star_border,
                            color: i < currentRating
                                ? const Color(0xFFFF6B35)
                                : Colors.grey,
                          ),
                          onPressed: () => _rate(i + 1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  s['descripcion'] ?? "Sin descripción",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                Text(
                  "Ubicación Exacta",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF6B35),
                  ),
                ),
                const SizedBox(height: 10),
                // MINI MAPA
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        double.tryParse(s['latitude'].toString()) ?? -33.4372,
                        double.tryParse(s['longitude'].toString()) ?? -70.6506,
                      ),
                      initialZoom: 15.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: UserData.isDarkMap 
                          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                          : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 50.0,
                            height: 50.0,
                            point: LatLng(
                              double.tryParse(s['latitude'].toString()) ?? -33.4372,
                              double.tryParse(s['longitude'].toString()) ?? -70.6506,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF6B35).withOpacity(0.6),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.skateboarding,
                                  color: Colors.white,
                                  size: 25,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // ADMIN: Delete Spot Button
                if (UserData.isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text("ELIMINAR SPOT (ADMIN)", style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () async {
                           bool confirm = await showDialog(
                             context: context, 
                             builder: (_) => AlertDialog(
                               title: const Text("¿Eliminar Spot?"),
                               content: const Text("Esta acción no se puede deshacer."),
                               actions: [
                                 TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text("Cancelar")),
                                 TextButton(onPressed: ()=>Navigator.pop(context,true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
                               ],
                             )
                           ) ?? false;
                           
                           if (confirm) {
                             bool ok = await ApiService.deleteSpot(widget.spot['id']);
                             if (ok && mounted) {
                               Navigator.pop(context, true); // Devuelve true para recargar
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Spot eliminado")));
                             }
                           }
                        },
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const Text(
                  "Comentarios",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                // LISTA DE COMENTARIOS (SIN Expanded porque estamos en un ListView vertical)
                comments.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text("Sé el primero en comentar."),
                      )
                    : ListView.builder(
                        shrinkWrap: true, // Importante para lista dentro de lista
                        physics: const NeverScrollableScrollPhysics(), // Scroll lo maneja el padre
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          var c = comments[index];
                          return Card(
                            color: Colors.black54,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(
                                  c['avatar'] ?? "https://via.placeholder.com/150"
                                ),
                                radius: 20,
                              ),
                              title: Text(
                                c['user'] ?? "Anónimo",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(c['texto'] ?? ""),
                              trailing: UserData.isAdmin 
                                  ? IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () async {
                                         if (c['id'] == null) return;
                                         bool confirm = await showDialog(
                                           context: context,
                                           builder: (_) => AlertDialog(
                                             title: const Text("Borrar comentario?"),
                                             actions: [
                                               TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text("No")),
                                               TextButton(onPressed: ()=>Navigator.pop(context,true), child: const Text("Sí", style: TextStyle(color: Colors.red))),
                                             ],
                                           )
                                         ) ?? false;
                                         
                                         if (confirm) {
                                            bool ok = await ApiService.deleteComment(c['id']);
                                            if (ok && mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Comentario eliminado")));
                                              setState((){}); // Recargar UI idealmente
                                            }
                                         }
                                      },
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          _commentCtrl, // ✅ CORREGIDO: Nombre de variable
                      decoration: const InputDecoration(
                        hintText: "Escribe...",
                        filled: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sendComment,
                    icon: const Icon(Icons.send, color: Colors.deepOrange),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- COMPETENCIA (VERSIÓN CORRECTA) ----------------
class CompeteScreen extends StatefulWidget {
  const CompeteScreen({super.key});
  @override
  State<CompeteScreen> createState() => _CompeteScreenState();
}

class _CompeteScreenState extends State<CompeteScreen> {
  List pendingChallenges = [];
  int pendingCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadPendingChallenges();
    
    // Verificar retos pendientes cada 5 segundos
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadPendingChallenges();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _loadPendingChallenges() async {
    var challenges = await ApiService.getPendingChallenges(UserData.id);
    if (mounted) {
      setState(() {
        // Si hay nuevos retos, mostrar notificación
        if (challenges.length > pendingCount && pendingCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("¡Tienes ${challenges.length} reto(s) pendiente(s)!"),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        pendingChallenges = challenges;
        pendingCount = challenges.length;
      });
    }
  }

  void _showPendingChallenges() {
    if (pendingChallenges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No tienes retos pendientes")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: pendingChallenges.length,
        itemBuilder: (c, i) {
          var challenge = pendingChallenges[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(challenge['challenger_avatar'] ?? ""),
            ),
            title: Text(challenge['challenger_name'] ?? "Desconocido"),
            subtitle: const Text("Te ha retado a S.K.A.T.E."),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () async {
                    Navigator.pop(context);
                    bool success = await ApiService.acceptChallenge(
                      challenge['id_duelo'],
                      UserData.id,
                    );
                    if (success && mounted) {
                      _loadPendingChallenges();
                      // Navegar a la pantalla de duelo
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActiveDuelScreen(
                            duelData: {
                              'id_duelo': challenge['id_duelo'],
                              'id_retado': UserData.id,
                            },
                            rivalName: challenge['challenger_name'],
                          ),
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () async {
                    Navigator.pop(context);
                    bool success = await ApiService.rejectChallenge(
                      challenge['id_duelo'],
                      UserData.id,
                    );
                    if (success && mounted) {
                      _loadPendingChallenges();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Reto rechazado")),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _startSkate() async {
    List users = await ApiService.getUsers(UserData.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (c, i) {
          var u = users[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(u['avatar'] ?? ""),
            ),
            title: Text(u['nickname']),
            subtitle: Text("Level: ${u['level'] ?? 'Novato'}"),
            trailing: FilledButton(
              child: const Text("DESAFIAR"),
              onPressed: () async {
                Navigator.pop(context);
                
                // Mostrar diálogo de carga
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                var duelData = await ApiService.createDuel(
                  UserData.id,
                  u['id_usuario'],
                );
                
                if (mounted) {
                  Navigator.pop(context); // Cerrar diálogo de carga
                  
                  if (duelData != null) {
                    // Mostrar diálogo de espera con auto-navegación
                    _showWaitingDialog(context, duelData['id_duelo'], u);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Error al enviar el reto"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          );
        },
      ),
    );
  }

  void _showWaitingDialog(BuildContext context, int idDuelo, Map<String, dynamic> opponent) {
    Timer? pollTimer;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
          var status = await ApiService.getChallengeStatus(idDuelo);
          if (status != null && status['estado'] == 'en_curso') {
            timer.cancel();
            if (Navigator.canPop(dialogContext)) Navigator.pop(dialogContext);
            if (mounted) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ActiveDuelScreen(
                  duelData: {'id_duelo': idDuelo, 'id_retado': opponent['id_usuario']},
                  rivalName: opponent['nickname'],
                ),
              ));
            }
          } else if (status != null && status['estado'] == 'rechazado') {
            timer.cancel();
            if (Navigator.canPop(dialogContext)) Navigator.pop(dialogContext);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${opponent['nickname']} rechazó el reto"), backgroundColor: Colors.red),
              );
            }
          }
        });
        return WillPopScope(
          onWillPop: () async { pollTimer?.cancel(); return true; },
          child: AlertDialog(
            title: const Text("RETO ENVIADO"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 40, backgroundImage: NetworkImage(opponent['avatar'] ?? "")),
                const SizedBox(height: 16),
                Text("Esperando que ${opponent['nickname']} acepte el reto...", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
            ),
            actions: [TextButton(onPressed: () { pollTimer?.cancel(); Navigator.pop(dialogContext); _loadPendingChallenges(); }, child: const Text("Cerrar"))],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'COMPETENCIA',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: _showPendingChallenges,
              ),
              if (pendingCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.5),
                          blurRadius: 5,
                        )
                      ],
                    ),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (pendingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: ElevatedButton.icon(
                    onPressed: _showPendingChallenges,
                    icon: const Icon(Icons.notifications_active),
                    label: Text(
                      "$pendingCount RETO${pendingCount > 1 ? 'S' : ''} PENDIENTE${pendingCount > 1 ? 'S' : ''}",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: _startSkate,
                child: Container(
                  width: 300,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF6B35).withOpacity(0.1),
                        ),
                        child: const Icon(Icons.flash_on, size: 40, color: Color(0xFFFF6B35)),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "S.K.A.T.E.",
                        style: GoogleFonts.outfit(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                      ),
                      Text(
                        "DESAFIAR A UN AMIGO",
                        style: GoogleFonts.inter(
                          color: Colors.white54, 
                          fontSize: 12, 
                          letterSpacing: 2
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
               // --- NUEVO BOTÓN MINI-JUEGO ---
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SkateGameScreen()),
                  );
                },
                child: Container(
                  width: 300,
                  height: 150,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blueAccent.withOpacity(0.1),
                        ),
                        child: const Icon(Icons.sports_esports, size: 30, color: Colors.blueAccent),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SKATE STREET",
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "ENTRENAMIENTO SOLO",
                            style: GoogleFonts.inter(
                              color: Colors.white54, 
                              fontSize: 10, 
                              letterSpacing: 1
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- PANTALLA DUELO ----------------
class ActiveDuelScreen extends StatefulWidget {
  final Map<String, dynamic> duelData;
  final String rivalName;
  const ActiveDuelScreen({
    super.key,
    required this.duelData,
    required this.rivalName,
  });
  @override
  State<ActiveDuelScreen> createState() => _ActiveDuelScreenState();
}

class _ActiveDuelScreenState extends State<ActiveDuelScreen> {
  String letrasYo = "";
  String letrasRival = "";
  bool gameOver = false;
  String msg = "";

  void _penalize(int idPerdedor) async {
    var res = await ApiService.penalize(
      widget.duelData['id_duelo'],
      idPerdedor,
    );
    if (res != null) {
      print("📥 Respuesta penalize: $res");
      
      setState(() {
        // El backend devuelve "SKA|S" donde la primera parte es challenger y la segunda es opponent
        String letrasActuales = res['letras_actuales'] ?? "|";
        List<String> parts = letrasActuales.split("|");
        
        // Determinar quién es quién
        bool yoSoyChallenger = UserData.id != widget.duelData['id_retado'];
        
        if (yoSoyChallenger) {
          // Yo soy el challenger (primera parte)
          letrasYo = parts.isNotEmpty ? parts[0] : "";
          letrasRival = parts.length > 1 ? parts[1] : "";
        } else {
          // Yo soy el opponent (segunda parte)
          letrasYo = parts.length > 1 ? parts[1] : "";
          letrasRival = parts.isNotEmpty ? parts[0] : "";
        }
        
        // IMPORTANTE: Actualizar game over DESPUÉS de las letras
        if (res['game_over'] == true) {
          gameOver = true;
          msg = res['ganador'] ?? "¡Juego terminado!";
          print("🏆 GAME OVER: $msg");
          print("📊 Letras finales - Yo: $letrasYo, Rival: $letrasRival");
          
          // Dar tiempo para que el usuario vea el resultado antes de volver
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text(
          "DUELO EN CURSO",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A0A0A),
              const Color(0xFF1A1A1A),
              const Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: Column(
          children: [
            // GAME OVER BANNER
            if (gameOver)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6B35),
                      const Color(0xFFFF8C42),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            
            const SizedBox(height: 40),
            
            // JUGADOR 1 (YO)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF6B35).withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      UserData.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF6B35),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // LETRAS CON ESTILO
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      child: Text(
                        letrasYo.isEmpty ? "—" : letrasYo,
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 18,
                          shadows: [
                            Shadow(
                              color: const Color(0xFFFF6B35).withOpacity(0.5),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    if (!gameOver)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 30),
                        child: ElevatedButton(
                          onPressed: () => _penalize(UserData.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_circle_outline, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "FALLÉ",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // SEPARADOR VS
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "VS",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF666666),
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
            
            // JUGADOR 2 (RIVAL)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF2A2A2A),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.rivalName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF666666),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // LETRAS DEL RIVAL
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      child: Text(
                        letrasRival.isEmpty ? "—" : letrasRival,
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF4A4A4A),
                          letterSpacing: 18,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    if (!gameOver)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 30),
                        child: ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2A2A2A),
                            disabledBackgroundColor: const Color(0xFF2A2A2A),
                            foregroundColor: const Color(0xFF666666),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.block, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "BLOQUEADO",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ---------------- PERFIL COMPLETO ----------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  final _edadCtrl = TextEditingController();
  final _comunaCtrl = TextEditingController();
  final _crewCtrl = TextEditingController();
  final _trayectoriaCtrl = TextEditingController();
  String _stance = "Regular";
  
  // Estadísticas de retos
  Map<String, dynamic> stats = {
    'total_retos': 0,
    'retos_ganados': 0,
    'retos_perdidos': 0,
    'win_rate': 0.0,
  };
  
  int _unreadMessagesCount = 0;
  Timer? _messagesTimer;

  @override
  void initState() {
    super.initState();
    _edadCtrl.text = UserData.edad.toString();
    _comunaCtrl.text = UserData.comuna;
    _crewCtrl.text = UserData.crew;
    _trayectoriaCtrl.text = UserData.trayectoria;
    if (UserData.stance.isNotEmpty) _stance = UserData.stance;
    _loadStats();
    _loadUnreadCount();
    
    // Revisar mensajes no leídos cada 10 segundos
    _messagesTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadUnreadCount();
    });
  }
  
  @override
  void dispose() {
    _messagesTimer?.cancel();
    super.dispose();
  }

  void _loadStats() async {
    var userStats = await ApiService.getUserStats(UserData.id);
    if (userStats != null && mounted) {
      setState(() {
        stats = userStats;
      });
    }
  }
  
  Future<void> _loadUnreadCount() async {
    try {
      final unread = await ApiService.getUnreadMessages(UserData.id);
      if (mounted) {
        int total = 0;
        for (var item in unread) {
          total += (item['cantidad'] as int?) ?? 0;
        }
        setState(() {
          _unreadMessagesCount = total;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  void _saveProfile() async {
    await ApiService.updateProfile(
      UserData.id,
      UserData.avatar,
      int.tryParse(_edadCtrl.text) ?? 0,
      _comunaCtrl.text,
      _crewCtrl.text,
      _stance,
      _trayectoriaCtrl.text,
    );
    UserData.edad = int.tryParse(_edadCtrl.text) ?? 0;
    UserData.comuna = _comunaCtrl.text;
    UserData.crew = _crewCtrl.text;
    UserData.stance = _stance;
    UserData.trayectoria = _trayectoriaCtrl.text;
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Perfil Guardado ✅")));
    }
  }

  void _changePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        UserData.avatar = "data:image/jpeg;base64,${base64Encode(bytes)}";
      });
    }
  }

  ImageProvider _getImageProvider(String imgString) {
    if (imgString.startsWith('http')) return NetworkImage(imgString);
    if (imgString.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(imgString.split(',').last));
      } catch (e) {
        return const NetworkImage("https://via.placeholder.com/150");
      }
    }
    return const NetworkImage(
      "https://images.unsplash.com/photo-1544005313-94ddf0286df2",
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "PERFIL",
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
             icon: const Icon(Icons.refresh, color: Color(0xFFFF6B35)),
             onPressed: () {
               _loadStats();
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Actualizando datos...")),
               );
             },
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveProfile),
          Badge(
            label: _unreadMessagesCount > 0 ? Text('$_unreadMessagesCount') : null,
            isLabelVisible: _unreadMessagesCount > 0,
            backgroundColor: const Color(0xFFFF6B35),
            child: IconButton(
              icon: const Icon(Icons.message, color: Color(0xFFFF6B35)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MessagesScreen()),
                ).then((_) {
                  // Recargar contador al volver del chat
                  _loadUnreadCount();
                });
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              UserData.clear();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _changePhoto,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        )
                      ],
                      border: Border.all(color: const Color(0xFFFF6B35), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: _getImageProvider(UserData.avatar),
                      child: const Icon(Icons.camera_alt, color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  UserData.name.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 28, 
                    fontWeight: FontWeight.w900, 
                    color: Colors.white,
                    letterSpacing: 2
                  ),
                ),
                Text(
                  UserData.level.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF6B35), 
                    letterSpacing: 3, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 30),
                
                // 🛹 ECONOMY STATS
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "PROGRESO",
                        style: GoogleFonts.outfit(
                          fontSize: 18, 
                          fontWeight: FontWeight.w800,
                          color: Colors.white54
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.leaderboard, color: Color(0xFFFF6B35)),
                        onPressed: () => Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => const LeaderboardScreen())
                        ),
                        tooltip: "Ranking",
                      )
                    ],
                  ),
                ),
                Row(
                  children: [
                     _buildStatCard("PUNTOS", "${UserData.puntosActuales}", Icons.stars, const Color(0xFFFF6B35)),
                     const SizedBox(width: 10),
                     _buildStatCard("RACHA", "${UserData.rachaActual}", Icons.local_fire_department, Colors.orangeAccent),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35).withOpacity(0.2),
                      foregroundColor: const Color(0xFFFF6B35),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: const BorderSide(color: Color(0xFFFF6B35)),
                      )
                    ),
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => const RewardsScreen())
                    ).then((_) => setState(() {})),
                    icon: const Icon(Icons.card_giftcard),
                    label: Text(
                      "CANJEAR PREMIOS",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // 📊 ESTADÍSTICAS
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Text(
                    "COMPETENCIA",
                    style: GoogleFonts.outfit(
                      fontSize: 18, 
                      fontWeight: FontWeight.w800,
                      color: Colors.white54
                    ),
                  ),
                ),
                Row(
                  children: [
                    _buildStatCard("TOTAL", "${stats['total_retos']}", Icons.sports_kabaddi, Colors.blue),
                    const SizedBox(width: 10),
                    _buildStatCard("VICTORIAS", "${stats['retos_ganados']}", Icons.emoji_events, Colors.green),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildStatCard("DERROTAS", "${stats['retos_perdidos']}", Icons.thumb_down, Colors.red),
                    const SizedBox(width: 10),
                    _buildStatCard("WIN RATE", "${stats['win_rate']}%", Icons.trending_up, Colors.orange),
                  ],
                ),
                
                const SizedBox(height: 40),
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Text(
                    "EDITAR INFO",
                    style: GoogleFonts.outfit(
                      fontSize: 18, 
                      fontWeight: FontWeight.w800,
                      color: Colors.white54
                    ),
                  ),
                ),

                _buildNeonInput(_edadCtrl, "EDAD", Icons.cake, keyboardType: TextInputType.number),
                const SizedBox(height: 15),
                _buildNeonInput(_comunaCtrl, "COMUNA", Icons.map),
                const SizedBox(height: 15),
                _buildNeonInput(_crewCtrl, "CREW", Icons.group),
                const SizedBox(height: 15),
                _buildNeonInput(_trayectoriaCtrl, "TRAYECTORIA (AÑOS)", Icons.history),
                const SizedBox(height: 15),
                
                // Dropdown estilizado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _stance,
                      dropdownColor: const Color(0xFF1A1A1A),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFF6B35)),
                      style: GoogleFonts.inter(color: Colors.white),
                      items: ['Regular', 'Goofy'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _stance = v!),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _saveProfile,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                    ),
                    child: Text("GUARDAR CAMBIOS", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 80), // Espacio extra para scroll
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeonInput(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white54),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 5),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, letterSpacing: 1, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
// ---------------- ADD SPOT SCREEN (Updated for All Users) ----------------
class AddSpotScreen extends StatefulWidget {
  const AddSpotScreen({super.key});
  @override
  State<AddSpotScreen> createState() => _AddSpotScreenState();
}

class _AddSpotScreenState extends State<AddSpotScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _type = 'Street';
  XFile? _imageFile; // Para móvil/web
  String? _webImageBase64;
  bool _locating = false;
  LatLng? _currentLoc;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  void _getLocation() async {
    setState(() => _locating = true);
    try {
      Position p = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLoc = LatLng(p.latitude, p.longitude);
          _locating = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (kIsWeb) {
        var bytes = await image.readAsBytes();
        setState(() {
          _imageFile = image;
          _webImageBase64 = "data:image/jpeg;base64,${base64Encode(bytes)}";
        });
      } else {
        setState(() {
          _imageFile = image;
        });
      }
    }
  }

  void _submit() async {
    if (_nameCtrl.text.isEmpty || _currentLoc == null || (_imageFile == null && _webImageBase64 == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nombre, Imagen y Ubicación requeridos")),
      );
      return;
    }
    setState(() => _uploading = true);

    String imgToSend = kIsWeb ? _webImageBase64! : _imageFile!.path;

    bool ok = await ApiService.createSpot(
      _nameCtrl.text,
      "GPS", // Ubicación detectada
      _type,
      _descCtrl.text,
      imgToSend,
      _currentLoc!.latitude,
      _currentLoc!.longitude,
    );

    if (mounted) {
      setState(() => _uploading = false);
      if (ok) {
        Navigator.pop(context, true); // Retornar true para recargar feed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Spot creado con éxito!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al crear spot"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AGREGAR SPOT")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white24),
                  image: (_webImageBase64 != null)
                      ? DecorationImage(image: MemoryImage(base64Decode(_webImageBase64!.split(',').last)), fit: BoxFit.cover)
                      : (_imageFile != null && !kIsWeb)
                          ? DecorationImage(image: NetworkImage("File logic not for web"), fit: BoxFit.cover) 
                          : null,
                ),
                child: (_imageFile == null)
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 50, color: Colors.white54),
                          SizedBox(height: 10),
                          Text("Toca para agregar foto", style: TextStyle(color: Colors.white54)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: "Nombre del Spot", border: OutlineInputBorder()),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: "Descripción", border: OutlineInputBorder()),
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _type,
              dropdownColor: Colors.grey[900],
              items: ['Street', 'Park', 'Ditch', 'Plaza'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _type = v!),
              decoration: const InputDecoration(labelText: "Tipo de Spot", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFFFF6B35)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _locating
                          ? "Buscando GPS..."
                          : _currentLoc != null
                              ? "GPS detectado: ${_currentLoc!.latitude.toStringAsFixed(4)}, ${_currentLoc!.longitude.toStringAsFixed(4)}"
                              : "GPS no detectado",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _getLocation),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _uploading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white),
                child: _uploading ? const CircularProgressIndicator(color: Colors.white) : const Text("PUBLICAR SPOT"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// 💬 CHAT SCREEN - APPEND THIS TO END OF main.dart

// 💬 CHAT SCREEN - APPEND THIS TO END OF main.dart

// Add this at the end of main.dart (after ProfileScreen class)

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> otherUser;
  const ChatScreen({super.key, required this.otherUser});
  
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<dynamic> messages = [];
  final _msgController = TextEditingController();
  Timer? _refreshTimer;
  bool loading = true;
  
  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAsRead();
    
    // Refresh cada 5 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _msgController.dispose();
    super.dispose();
  }

  void _loadMessages() async {
    // Si es la primera carga, no mostrar indicador a menos que esté vacío
    // Pero aquí simplificamos
    var msgs = await ApiService.getMessages(
      UserData.id, 
      widget.otherUser['id_usuario'],
    );
    if (mounted) {
      setState(() {
        messages = msgs;
        loading = false;
        // Ordenar: backend suele dar cronológico. Nosotros mostramos reverse.
        // Si backend da ASC (antiguos primero), aquí llegan ASC.
        // ListView reverse: true muestra el ÚLTIMO elemento abajo.
      });
    }
  }

  void _markAsRead() async {
    // Implementar en backend si existe endpoint 'markRead'
  }

  void _sendMessage() async {
    String txt = _msgController.text.trim();
    if (txt.isEmpty) return;
    
    _msgController.clear();
    bool ok = await ApiService.sendMessage(
      UserData.id,
      widget.otherUser['id_usuario'],
      txt,
    );
    if (ok) {
      _loadMessages(); // Recargar chat
    }
  }
  
  String _formatTime(String? iso) {
    if (iso == null) return "";
    try {
      DateTime dt = DateTime.parse(iso).toLocal();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "";
    }
  }

  ImageProvider _getImageProvider(String imgString) {
    if (imgString.startsWith('http')) return NetworkImage(imgString);
    if (imgString.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(imgString.split(',').last));
      } catch (e) {
        return const NetworkImage("https://via.placeholder.com/150");
      }
    }
    return const NetworkImage("https://images.unsplash.com/photo-1564982752979-3f7bc974d29a");
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: _getImageProvider(widget.otherUser['avatar'] ?? ""),
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherUser['nickname'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.black,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? const Center(
                          child: Text(
                            "No hay mensajes.\nEscribe algo para comenzar 👇",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          reverse: true, // Últimos mensajes abajo
                          itemCount: messages.length,
                          itemBuilder: (c, i) {
                            // Como está reverse, invertimos el índice
                            var msg = messages[messages.length - 1 - i];
                            bool isMine = msg['id_remitente'] == UserData.id;
                            
                            return Align(
                              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                padding: const EdgeInsets.all(12),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                                ),
                                decoration: BoxDecoration(
                                  color: isMine ? Colors.deepOrange : Colors.grey[700],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      msg['texto'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(msg['fecha_envio']),
                                      style: TextStyle(
                                        color: isMine ? Colors.white60 : Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  child: Container(
                    color: Colors.black,
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _msgController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Escribe un mensaje...",
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.deepOrange,
                          child: IconButton(
                            onPressed: _sendMessage,
                            icon: const Icon(Icons.send, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

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
  List<dynamic> filteredPosts = [];
  bool loading = true;
  final ScrollController _scrollController = ScrollController();
  int _currentOffset = 0;
  final int _limit = 20;
  String _selectedFilter = 'all'; // 'all', 'general', 'ventas', 'news'

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
        _applyFilter();
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
        _applyFilter();
        _currentOffset += data.length;
      });
    }
  }

  void _applyFilter() {
    if (_selectedFilter == 'all') {
      filteredPosts = List.from(posts);
    } else {
      filteredPosts = posts.where((post) => post['tipo'] == _selectedFilter).toList();
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  void _showCreatePostDialog() {
    final _textCtrl = TextEditingController();
    String _tipo = 'general';
    String _selectedImage = '';
    final _picker = ImagePicker();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Nueva Publicación', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
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
                
                // IMAGE PICKER BUTTON
                OutlinedButton.icon(
                  onPressed: () async {
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      final bytes = await image.readAsBytes();
                      final base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
                      setDialogState(() => _selectedImage = base64Image);
                    }
                  },
                  icon: const Icon(Icons.image, color: Color(0xFFFF6B35)),
                  label: Text(
                    _selectedImage.isEmpty ? 'Agregar Imagen' : 'Imagen Seleccionada ✓',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF6B35)),
                  ),
                ),
                
                if (_selectedImage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      base64Decode(_selectedImage.split(',')[1]),
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setDialogState(() => _selectedImage = ''),
                    child: const Text('Quitar imagen', style: TextStyle(color: Colors.red)),
                  ),
                ],
                
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
                    DropdownMenuItem(value: 'ventas', child: Text('Ventas')),
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
                  _selectedImage,
                  _tipo,
                );
                
                if (mounted) {
                  Navigator.pop(ctx);
                  if (success) {
                    _loadPosts();
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
        title: const Text('FEED SOCIAL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPosts,
          ),
        ],
      ),
      body: Column(
        children: [
          // FILTER CHIPS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            color: const Color(0xFF0A0A0A),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Todos', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('General', 'general'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Ventas', 'ventas'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Noticias', 'news'),
                ],
              ),
            ),
          ),
          // POSTS LIST
          Expanded(
            child: loading && filteredPosts.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  )
                : RefreshIndicator(
                    onRefresh: _loadPosts,
                    color: const Color(0xFFFF6B35),
                    child: filteredPosts.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                              const Icon(
                                Icons.filter_alt_off,
                                size: 80,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'No hay publicaciones con este filtro',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: filteredPosts.length,
                            itemBuilder: (context, index) {
                              return _PostCard(
                                post: filteredPosts[index],
                                onLike: () async {
                                  final result = await ApiService.toggleLike(
                                    filteredPosts[index]['id_post'],
                                    UserData.id,
                                  );
                                  if (result != null && mounted) {
                                    setState(() {
                                      filteredPosts[index]['likes_count'] = result['likes_count'];
                                    });
                                  }
                                },
                                onComment: () {
                                  _showCommentDialog(filteredPosts[index]);
                                },
                                onViewComments: () {
                                  _showViewCommentsDialog(filteredPosts[index]);
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => _onFilterChanged(value),
      backgroundColor: const Color(0xFF1A1A1A),
      selectedColor: const Color(0xFFFF6B35),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFFFF6B35) : Colors.white24,
        width: 1.5,
      ),
    );
  }

  void _showViewCommentsDialog(Map<String, dynamic> post) async {
    final comments = await ApiService.getPostComments(post['id_post']);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'Comentarios (${comments.length})',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: comments.isEmpty
              ? const Center(
                  child: Text(
                    'No hay comentarios aún',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final avatar = comment['usuario_avatar'] ?? 'https://images.unsplash.com/photo-1544005313-94ddf0286df2';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A0A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(avatar),
                            backgroundColor: Colors.white10,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment['usuario_nombre'] ?? 'Usuario',
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B35),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  comment['texto'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // DELETE BUTTON (Icono Unificado)
                          if (comment['id_usuario'] == UserData.id || UserData.isAdmin)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18), // Icono sutil
                                tooltip: 'Eliminar comentario',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                                onPressed: () async {
                                  bool confirm = await showDialog(
                                    context: context,
                                    builder: (btx) => AlertDialog(
                                      backgroundColor: Colors.black,
                                      title: const Text('¿Eliminar?', style: TextStyle(color: Colors.white)),
                                      actions: [
                                        TextButton(onPressed: ()=>Navigator.pop(btx, false), child: const Text('No')),
                                        TextButton(onPressed: ()=>Navigator.pop(btx, true), child: const Text('Sí', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  ) ?? false;
                                  
                                  if (confirm) {
                                    final success = await ApiService.deletePostComment(comment['id_comment'], UserData.id);
                                    if (success) {
                                      if (mounted) {
                                        Navigator.pop(context); 
                                        _showViewCommentsDialog(post); 
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Comentario eliminado'), backgroundColor: Colors.redAccent),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: Color(0xFFFF6B35))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showCommentDialog(post);
            },
            child: const Text('Comentar'),
          ),
        ],
      ),
    );
  }

  void _showCommentDialog(Map<String, dynamic> post) {
    final _commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Agregar Comentario', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _commentCtrl,
          maxLines: 2,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Escribe tu comentario...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF0A0A0A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.white10),
            ),
          ),
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
              if (_commentCtrl.text.isEmpty) return;
              
              final success = await ApiService.addPostComment(
                post['id_post'],
                UserData.id,
                _commentCtrl.text,
              );
              
              if (mounted) {
                Navigator.pop(ctx);
                if (success) {
                  // Solo actualizar el contador localmente sin recargar todo
                  setState(() {
                    final postIndex = posts.indexWhere((p) => p['id_post'] == post['id_post']);
                    if (postIndex != -1) {
                      posts[postIndex]['comments_count'] = (posts[postIndex]['comments_count'] ?? 0) + 1;
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('💬 Comentario agregado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Comentar'),
          ),
        ],
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
  final VoidCallback onViewComments;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onViewComments,
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
        return '📰 NOTICIA';
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
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
                // DELETE BUTTON - LIMPIO
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Color(0xFFFF6B35), size: 22),
                  tooltip: 'Eliminar post',
                  onPressed: () async {
                    // Hardcoded: IDs 1 y 2 son admin
                    final isAdmin = (UserData.id == 1 || UserData.id == 2);
                    final isOwner = (post['id_usuario'] == UserData.id);
                    
                    if (!isAdmin && !isOwner) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No tienes permiso'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.black,
                        title: Text('¿Eliminar publicación?', style: TextStyle(color: Colors.white)),
                        content: Text('Esta acción no se puede deshacer', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancelar', style: TextStyle(color: Colors.white70)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      final success = await ApiService.deletePost(post['id_post'], UserData.id);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✅ Post eliminado'), backgroundColor: Colors.green),
                        );
                        (context.findAncestorStateOfType<_SocialFeedScreenState>())?._loadPosts();
                      }
                    }
                  },
                ),
                if (tipoBadge.isNotEmpty)
                  Container(
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
              ],
            ),
          ),
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
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
                InkWell(
                  onTap: onViewComments,
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
