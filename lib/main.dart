import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'dart:convert';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Erro ao buscar câmeras: $e");
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

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomePage({super.key, required this.cameras});

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
        debugPrint("Erro no vídeo: $e");
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
                    if (widget.cameras.isEmpty) {
                      _showNoCameraDialog(context);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MonitorPage(cameras: widget.cameras))
                      );
                    }
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

  void _showNoCameraDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Câmera não detectada"),
        content: const Text("Não conseguimos encontrar nenhuma câmera conectada ao seu dispositivo. Verifique as permissões do navegador ou a conexão do hardware."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      ),
    );
  }
}

class MonitorPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const MonitorPage({super.key, required this.cameras});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  CameraController? _controller;
  final FlutterTts _tts = FlutterTts();
  Timer? _detectionTimer;

  // Coordenadas normalizadas (0.0 a 1.0)
  List<Offset> polygonNormalized = [
    const Offset(0.2, 0.2), const Offset(0.8, 0.2),
    const Offset(0.8, 0.8), const Offset(0.2, 0.8),
  ];

  bool isAlerting = false;
  int? _draggingIndex;
  DateTime lastAlertTime = DateTime.now().subtract(const Duration(seconds: 10));

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("pt-BR");
    await _tts.setSpeechRate(0.5); // Velocidade natural
    await _tts.setPitch(1.0);
  }

  Future<void> _initCamera() async {
    // Usamos max para garantir a melhor resolução disponível no hardware
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});

      // Inicia o "cérebro" da detecção
      _startDetectionLoop();
    } catch (e) {
      debugPrint("Erro ao inicializar câmera: $e");
    }
  }

  void _startDetectionLoop() {
    // No ambiente Web real, este timer chamaria o MediaPipe via JS
    // Aqui simulamos o loop que verifica a área a cada 2 segundos
    _detectionTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      // Implementação futura: MediaPipe.detect(frame)
    });
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
    if (now.difference(lastAlertTime).inSeconds < 5) return;

    setState(() => isAlerting = true);

    try {
      final response = await http.post(
        Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/vision_alert"),
        body: jsonEncode({"area_name": "Perímetro Alfa", "object_type": "pessoa"}),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final msg = jsonDecode(response.body)['message'];
        // A voz é local (do navegador/celular) - Instantânea!
        await _tts.speak(msg);
        lastAlertTime = DateTime.now();
      }
    } catch (e) {
      await _tts.speak("Sistema em Alerta. Movimentação detectada.");
      lastAlertTime = DateTime.now();
    } finally {
      if (mounted) setState(() => isAlerting = false);
    }
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _controller?.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;

          final polygonPixels = polygonNormalized.map((offset) {
            return Offset(offset.dx * size.width, offset.dy * size.height);
          }).toList();

          return Stack(
            fit: StackFit.expand,
            children: [
              // Câmera Full Res
              Center(
                child: CameraPreview(_controller!),
              ),

              // Interface de Detecção
              GestureDetector(
                onPanStart: (details) {
                  final pos = details.localPosition;
                  for (int i = 0; i < polygonPixels.length; i++) {
                    if ((pos - polygonPixels[i]).distance < 45) {
                      setState(() => _draggingIndex = i);
                      return;
                    }
                  }
                  // Toque para teste manual
                  if (_isPointInPolygon(pos, polygonPixels)) {
                    _processAlert();
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
                  painter: PolygonPainter(polygon: polygonPixels, isAlerting: isAlerting),
                ),
              ),

              // Barra Superior
              Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: Text(isAlerting ? "STATUS: ALERTA!" : "STATUS: SEGURO",
                          style: TextStyle(color: isAlerting ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
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
      canvas.drawCircle(point, 10, Paint()..color = Colors.white);
      canvas.drawCircle(point, 5, Paint()..color = isAlerting ? Colors.red : Colors.green);
    }
  }

  @override
  bool shouldRepaint(PolygonPainter oldDelegate) => true;
}
