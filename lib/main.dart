import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    print("Erro: $e");
  }
  runApp(TerlineTEyesApp(cameras: cameras));
}

class TerlineTEyesApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const TerlineTEyesApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TerlineT Eyes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF27AE60),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: HomePage(cameras: cameras),
    );
  }
}

// --- TELA INICIAL COM VÍDEO BACKGROUND ---
class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomePage({super.key, required this.cameras});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset("assets/videos/yees.mp4")
      ..initialize().then((_) {
        _controller.setLooping(true);
        _controller.setVolume(0); // Mudo para permitir autoplay no navegador
        _controller.play();
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Vídeo de Fundo
          SizedBox.expand(
            child: _controller.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  )
                : Container(color: Colors.black),
          ),

          // 2. Overlay para escurecer o vídeo e destacar o texto
          Container(color: Colors.black.withOpacity(0.6)),

          // 3. Conteúdo da Interface
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 100, color: Color(0xFF27AE60)),
                const SizedBox(height: 20),
                Text("TERLINET EYES",
                    style: GoogleFonts.orbitron(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 10,
                        color: Colors.white)),
                const Text("SISTEMA DE MONITORAMENTO COM IA",
                    style: TextStyle(color: Colors.white54, letterSpacing: 5)),
                const SizedBox(height: 60),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => MonitorPage(cameras: widget.cameras))),
                  child: const Text("INICIAR SISTEMA",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- TELA DE MONITORAMENTO ---
class MonitorPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const MonitorPage({super.key, required this.cameras});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  late CameraController _controller;
  final FlutterTts _tts = FlutterTts();

  // Geometria da Área de Detecção
  List<Offset> polygon = [
    const Offset(100, 100), const Offset(400, 100),
    const Offset(400, 400), const Offset(100, 400),
  ];

  bool isAlerting = false;
  DateTime lastAlertTime = DateTime.now().subtract(const Duration(seconds: 10));
  int? _draggingIndex;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.cameras[0], ResolutionPreset.high);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _startDetectionLoop();
    });
    _tts.setLanguage("pt-BR");
  }

  // Loop de Detecção Simulando MediaPipe (Para Web Integration)
  void _startDetectionLoop() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) timer.cancel();
      // Aqui o MediaPipe enviaria as coordenadas das pessoas detectadas
      // Se detectado, chamamos _checkInvasion(pontoCentralPessoa)
    });
  }

  // Lógica de Invasão (Ray Casting Algorithm)
  bool _isPointInPolygon(Offset p, List<Offset> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      if (((poly[i].dy > p.dy) != (poly[j].dy > p.dy)) &&
          (p.dx < (poly[j].dx - poly[i].dx) * (p.dy - poly[i].dy) / (poly[j].dy - poly[i].dy) + poly[i].dx)) {
        inside = !inside;
      }
    }
    return inside;
  }

  Future<void> _processAlert() async {
    if (DateTime.now().difference(lastAlertTime).inSeconds < 5) return;
    lastAlertTime = DateTime.now();

    setState(() => isAlerting = true);

    try {
      final response = await http.post(
        Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/vision_alert"),
        body: jsonEncode({"area_name": "Web Zone", "object_type": "pessoa"}),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final msg = jsonDecode(response.body)['message'];
        await _tts.speak(msg);
      }
    } catch (e) {
      await _tts.speak("Atenção! Movimentação detectada.");
    } finally {
      if (mounted) setState(() => isAlerting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text("TERLINET EYES - LIVE FEED", style: GoogleFonts.orbitron(fontSize: 12)),
        backgroundColor: Colors.black,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(isAlerting ? "STATUS: ALERTA!" : "STATUS: SEGURO",
                style: TextStyle(color: isAlerting ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          // 1. Câmera Full Screen
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.previewSize?.height ?? 1280,
                height: _controller.value.previewSize?.width ?? 720,
                child: CameraPreview(_controller),
              ),
            ),
          ),

          // 2. Desenho do Polígono e Interação
          GestureDetector(
            onPanStart: (details) {
              // Verifica se o toque foi perto de algum vértice (raio de 30 para facilitar no celular)
              for (int i = 0; i < polygon.length; i++) {
                if ((details.localPosition - polygon[i]).distance < 30) {
                  setState(() => _draggingIndex = i);
                  break;
                }
              }
            },
            onPanUpdate: (details) {
              if (_draggingIndex != null) {
                setState(() {
                  polygon[_draggingIndex!] = details.localPosition;
                });
              }
            },
            onPanEnd: (details) {
              setState(() => _draggingIndex = null);
            },
            child: CustomPaint(
              size: Size.infinite,
              painter: PolygonPainter(polygon: polygon, isAlerting: isAlerting),
            ),
          ),

          // Instruções
          const Positioned(
            bottom: 20,
            left: 20,
            child: Text("Perímetro de Elite Ativo • MediaPipe AI Enabled",
              style: TextStyle(color: Colors.white54, fontSize: 10)),
          )
        ],
      ),
    );
  }
}

class PolygonPainter extends CustomPainter {
  final List<Offset> polygon;
  final bool isAlerting;
  PolygonPainter({required this.polygon, required this.isAlerting});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isAlerting ? Colors.red : Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = (isAlerting ? Colors.red : Colors.green).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path()..addPolygon(polygon, true);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    for (var point in polygon) {
      canvas.drawCircle(point, 6, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
