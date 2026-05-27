import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'services/js_bridge.dart' as bridge;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TerlineTEyesApp());
}

class TerlineTEyesApp extends StatelessWidget {
  const TerlineTEyesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TerlineT Eyes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF27AE60),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late VideoPlayerController _controller;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset("assets/videos/yees.mp4")
      ..initialize().then((_) {
        _controller.setLooping(true);
        _controller.setVolume(0);
        _controller.play();
        setState(() {});
      }).catchError((e) {
        setState(() => _isError = true);
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
          SizedBox.expand(
            child: !_isError && _controller.value.isInitialized
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
          Container(color: Colors.black.withOpacity(0.6)),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 100, color: Color(0xFF27AE60)),
                const SizedBox(height: 20),
                Text("TERLINET EYES",
                    style: GoogleFonts.orbitron(
                        fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 10, color: Colors.white)),
                const Text("SISTEMA DE MONITORAMENTO COM IA",
                    style: TextStyle(color: Colors.white54, letterSpacing: 5)),
                const SizedBox(height: 60),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MonitorPage()),
                    );
                  },
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

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  final FlutterTts _tts = FlutterTts();
  html.VideoElement? _videoElement;
  List<dynamic> _landmarks = [];
  bool _isAlerting = false;
  DateTime _lastAlertTime = DateTime.now().subtract(const Duration(seconds: 10));

  List<Offset> polygonNormalized = [
    const Offset(0.3, 0.2), const Offset(0.7, 0.2),
    const Offset(0.7, 0.8), const Offset(0.3, 0.8),
  ];
  int? _draggingIndex;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initCameraWeb();
    _setupPoseCallback();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("pt-BR");
    await _tts.setSpeechRate(0.5);
  }

  void _initCameraWeb() {
    // Injetando o vídeo diretamente no corpo do HTML para garantir visibilidade
    _videoElement = html.VideoElement()
      ..id = 'pose-video'
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true');

    html.document.body?.append(_videoElement!);

    // Inicia MediaPipe
    Future.delayed(const Duration(milliseconds: 500), () {
      bridge.initMediaPipe('pose-video');
    });
  }

  void _setupPoseCallback() {
    bridge.setPoseCallback((landmarksJson) {
      if (mounted) {
        final List<dynamic> newLandmarks = jsonDecode(landmarksJson);
        setState(() {
          _landmarks = newLandmarks;
        });
        _checkInvasion(newLandmarks);
      }
    });
  }

  void _checkInvasion(List<dynamic> landmarks) {
    if (landmarks.isEmpty) return;

    if (landmarks.length > 24) {
      // Ponto central baseado no quadril (23 e 24)
      double midX = (landmarks[23]['x'] + landmarks[24]['x']) / 2;
      double midY = (landmarks[23]['y'] + landmarks[24]['y']) / 2;

      // No MediaPipe Web, X é invertido na visualização, mas as coordenadas
      // seguem o padrão 0.0 a 1.0.
      Offset personPos = Offset(midX, midY);

      if (_isPointInPolygon(personPos, polygonNormalized)) {
        _processAlert();
      }
    }
  }

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
    final now = DateTime.now();
    if (now.difference(_lastAlertTime).inSeconds < 8) return;
    _lastAlertTime = now;

    setState(() => _isAlerting = true);

    try {
      final response = await http.post(
        Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/vision_alert"),
        body: jsonEncode({"area_name": "Perímetro Alfa", "object_type": "pessoa"}),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final msg = jsonDecode(response.body)['message'];
        await _tts.speak(msg);
      }
    } catch (e) {
      await _tts.speak("Acesso detectado na zona de segurança.");
    } finally {
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isAlerting = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _videoElement?.remove(); // Remove o vídeo do corpo do HTML ao sair
    _videoElement = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Importante: Deixar transparente para ver o vídeo atrás
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;

          final polygonPixels = polygonNormalized.map((offset) {
            return Offset(offset.dx * size.width, offset.dy * size.height);
          }).toList();

          return Stack(
            fit: StackFit.expand,
            children: [
              // O vídeo está no fundo (DOM), desenhamos o esqueleto por cima
              if (_landmarks.isNotEmpty)
                CustomPaint(
                  painter: PosePainter(_landmarks),
                  size: Size.infinite,
                ),

              GestureDetector(
                onPanStart: (details) {
                  final pos = details.localPosition;
                  for (int i = 0; i < polygonPixels.length; i++) {
                    if ((pos - polygonPixels[i]).distance < 50) {
                      setState(() => _draggingIndex = i);
                      return;
                    }
                  }
                },
                onPanUpdate: (details) {
                  if (_draggingIndex != null) {
                    setState(() {
                      double dx = (details.localPosition.dx / size.width).clamp(0.0, 1.0);
                      double dy = (details.localPosition.dy / size.height).clamp(0.0, 1.0);
                      polygonNormalized[_draggingIndex!] = Offset(dx, dy);
                    });
                  }
                },
                onPanEnd: (_) => setState(() => _draggingIndex = null),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: PolygonPainter(polygon: polygonPixels, isAlerting: _isAlerting),
                ),
              ),

              Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _isAlerting ? Colors.red : Colors.green),
                      ),
                      child: Text(
                        _isAlerting ? "STATUS: ALERTA!" : "STATUS: SEGURO",
                        style: TextStyle(
                          color: _isAlerting ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final List<dynamic> landmarks;
  PosePainter(this.landmarks);

  @override
  void paint(Canvas canvas, Size size) {
    final paintPoint = Paint()..color = const Color(0xFF27AE60)..style = PaintingStyle.fill;

    for (var lm in landmarks) {
      if (lm['visibility'] > 0.5) {
        // Mapeia coordenadas 0-1 para o tamanho da tela
        canvas.drawCircle(Offset(lm['x'] * size.width, lm['y'] * size.height), 4, paintPoint);
      }
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) => true;
}

class PolygonPainter extends CustomPainter {
  final List<Offset> polygon;
  final bool isAlerting;
  PolygonPainter({required this.polygon, required this.isAlerting});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isAlerting ? Colors.red.withOpacity(0.8) : Colors.green.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = (isAlerting ? Colors.red : Colors.green).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path()..addPolygon(polygon, true);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    for (var point in polygon) {
      canvas.drawCircle(point, 12, Paint()..color = Colors.white);
      canvas.drawCircle(point, 6, Paint()..color = isAlerting ? Colors.red : Colors.green);
    }
  }

  @override
  bool shouldRepaint(PolygonPainter oldDelegate) => true;
}
