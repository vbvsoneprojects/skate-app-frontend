
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart'; // For UserData and ApiService

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<dynamic>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = ApiService.getLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "TOP SKATERS",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A)],
          ),
        ),
        child: FutureBuilder<List<dynamic>>(
          future: _leaderboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      "Error al cargar ranking",
                      style: GoogleFonts.outfit(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }

            final users = snapshot.data ?? [];
            if (users.isEmpty) {
              return Center(
                child: Text(
                  "No hay skaters en el ranking aún",
                  style: GoogleFonts.outfit(color: Colors.white70),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final isMe = user['id_usuario'] == UserData.id;
                final rank = index + 1;
                
                Color rankColor;
                double scale = 1.0;
                
                if (rank == 1) {
                  rankColor = const Color(0xFFFFD700); // Gold
                  scale = 1.05;
                } else if (rank == 2) {
                  rankColor = const Color(0xFFC0C0C0); // Silver
                } else if (rank == 3) {
                  rankColor = const Color(0xFFCD7F32); // Bronze
                } else {
                  rankColor = Colors.white;
                }

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFFF6B35).withOpacity(0.2) : const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(16),
                      border: isMe 
                          ? Border.all(color: const Color(0xFFFF6B35), width: 1.5)
                          : Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      // activeColor removed as it is not a valid parameter
                      leading: SizedBox(
                        width: 50,
                        child: Row(
                          children: [
                            if (rank <= 3) ...[
                              Icon(Icons.emoji_events, color: rankColor, size: 20),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              "#$rank",
                              style: GoogleFonts.outfit(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: rankColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        user['nickname'] ?? 'Skater',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        "${user['comuna'] ?? 'Chile'}",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${user['mejor_puntaje'] ?? 0} PTS",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFFF6B35),
                                fontSize: 14,
                              ),
                            ),
                            if ((user['mejor_racha'] ?? 0) > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${user['mejor_racha']}🔥",
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
