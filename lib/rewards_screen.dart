
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart'; // For UserData and ApiService

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  late Future<List<dynamic>> _rewardsFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  void _loadRewards() {
    setState(() {
      _rewardsFuture = ApiService.getRewards();
    });
  }

  Future<void> _claimReward(Map<String, dynamic> reward) async {
    if (UserData.puntosActuales < (reward['costo_puntos'] as int)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡No tienes suficientes puntos! Sigue jugando 🛹"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Call API
    final result = await ApiService.claimReward(UserData.id, reward['id_reward']);

    setState(() => _isLoading = false);

    if (result != null && result['success'] == true) {
      // Update local points
      setState(() {
        UserData.puntosActuales -= (reward['costo_puntos'] as int);
      });
      
      if (!mounted) return;

      // Show Success Dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            "¡CANJE EXITOSO!",
            style: GoogleFonts.outfit(
              color: const Color(0xFFFF6B35),
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
              const SizedBox(height: 16),
              Text(
                "Tu código de canje es:",
                style: GoogleFonts.inter(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              SelectableText(
                result['codigo_canje'] ?? "ERROR",
                style: GoogleFonts.robotoMono(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Guarda este código o toma una captura. Lo necesitarás para validar tu premio.",
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("ENTENDIDO", style: TextStyle(color: Color(0xFFFF6B35))),
            ),
          ],
        ),
      );
      
      // Reload rewards to update stock
      _loadRewards();

    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result?['mensaje'] ?? "Error al canjear premio"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "RECOMPENSAS",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  "${UserData.puntosActuales}",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          )
        ],
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
        child: Stack(
          children: [
            FutureBuilder<List<dynamic>>(
              future: _rewardsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error cargando premios",
                      style: GoogleFonts.outfit(color: Colors.white70),
                    ),
                  );
                }

                final rewards = snapshot.data ?? [];
                if (rewards.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          "No hay premios disponibles por ahora.\n¡Vuelve pronto!",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: rewards.length,
                  itemBuilder: (context, index) {
                    final reward = rewards[index];
                    final canAfford = UserData.puntosActuales >= (reward['costo_puntos'] as int);
                    final hasStock = (reward['stock_disponible'] as int) > 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Image Placeholder
                          Expanded(
                            flex: 3,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              child: Center(
                                child: Text(
                                  "🎁", // Emoji as placeholder image
                                  style: const TextStyle(fontSize: 48),
                                ),
                                // In future: Image.network(reward['imagen_url']...)
                              ),
                            ),
                          ),
                          
                          // Content
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reward['nombre'] ?? "Premio",
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    reward['descripcion'] ?? "",
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.white54,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${reward['costo_puntos']} pts",
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w900,
                                          color: canAfford ? const Color(0xFFFF6B35) : Colors.white38,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        "Stock: ${reward['stock_disponible']}",
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: hasStock ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 32,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: canAfford && hasStock 
                                            ? const Color(0xFFFF6B35) 
                                            : Colors.grey[800],
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                      onPressed: (canAfford && hasStock) 
                                          ? () => _claimReward(reward) 
                                          : null,
                                      child: Text(
                                        hasStock 
                                            ? (canAfford ? "CANJEAR" : "FALTAN PUNTOS")
                                            : "AGOTADO",
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
