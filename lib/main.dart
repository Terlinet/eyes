import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

// --- Ponte JS Interop ---
@JS('initPoseDetector')
external JSPromise<JSBoolean> _initPoseDetector();

@JS('startCamera')
external JSPromise<JSBoolean> _startCamera();

@JS('stopCamera')
external void _stopCamera();

@JS('setPoseCallback')
external void _setPoseCallback(JSFunction callback);

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

class _MonitorPageState extends State<MonitorPage> with TickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  List<dynamic> _landmarks = [];
  bool _isAlerting = false;
  bool _isSpeaking = false;
  String _subtitle = "";
  Timer? _typewriterTimer;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  DateTime _lastAlertTime = DateTime.now().subtract(const Duration(seconds: 10));

  // Coordenadas do polígono (Normalizadas 0.0 a 1.0)
  List<Offset> polygonNormalized = [
    const Offset(0.3, 0.2), const Offset(0.7, 0.2),
    const Offset(0.7, 0.8), const Offset(0.3, 0.8),
  ];
  int? _draggingIndex;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _initTts().then((_) => _speakIntroduction());
    _setupPoseDetection();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("pt-BR");
    await _tts.setSpeechRate(0.8); // Velocidade aumentada para ser dinâmica
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() => setState(() => _isSpeaking = true));
    _tts.setCompletionHandler(() => setState(() => _isSpeaking = false));
    _tts.setErrorHandler((msg) => setState(() => _isSpeaking = false));
  }

  Future<void> _speakIntroduction() async {
    // Pequeno atraso para garantir que o usuário está pronto
    await Future.delayed(const Duration(seconds: 2));
    const text = "Bem-vindo ao TerlineT Eyes. Este sistema utiliza inteligência artificial para monitoramento de segurança em tempo real. "
      "Ajuste o perímetro verde arrastando os círculos brancos para definir a zona restrita. "
      "Qualquer presença humana detectada nesta área ativará um alerta imediato. O sistema está operacional.";
    _typeSubtitle(text);
    await _tts.speak(text);
  }

  void _typeSubtitle(String text) {
    _typewriterTimer?.cancel();
    setState(() {
      _subtitle = "";
      _isSpeaking = true;
    });

    int charIndex = 0;
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (charIndex < text.length) {
        setState(() {
          _subtitle += text[charIndex];
        });
        charIndex++;
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _setupPoseDetection() async {
    _setPoseCallback(_onPoseDetected.toJS);
    final initSuccess = await _initPoseDetector().toDart;
    if (initSuccess.toDart) {
      await _startCamera().toDart;
    }
  }

  void _onPoseDetected(JSString landmarksJson) {
    if (!mounted) return;
    final List<dynamic> newLandmarks = jsonDecode(landmarksJson.toDart);
    setState(() {
      _landmarks = newLandmarks;
    });
    _checkInvasion(newLandmarks);
  }

  void _checkInvasion(List<dynamic> landmarks) {
    if (landmarks.isEmpty) return;

    bool anyPartInside = false;

    for (var lm in landmarks) {
      if (lm['visibility'] > 0.5) {
        // Inverte o X por causa do espelhamento da câmera frontal
        double x = 1.0 - (lm['x'] as num).toDouble();
        double y = (lm['y'] as num).toDouble();

        if (_isPointInPolygon(Offset(x, y), polygonNormalized)) {
          anyPartInside = true;
          break;
        }
      }
    }

    if (anyPartInside) {
      _processAlert();
    }
  }

  Widget _buildCyberCube() {
    final cubeColor = _isAlerting ? Colors.red : const Color(0xFF27AE60);
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _rotationController]),
      builder: (context, child) {
        final pulse = 1.0 + (_pulseController.value * 0.2);
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(_rotationController.value * 6.28)
            ..rotateY(_rotationController.value * 6.28)
            ..scale(pulse),
          alignment: Alignment.center,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: cubeColor.withOpacity(0.2),
              border: Border.all(color: cubeColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: cubeColor.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _isAlerting ? Icons.warning_amber_rounded : Icons.auto_awesome,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
            ),
          ),
        );
      },
    );
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
        body: jsonEncode({
          "area_name": "Perímetro Alfa",
          "object_type": "presença humana detectada",
          "severity": "high"
        }),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final msg = jsonDecode(response.body)['message'];
        _typeSubtitle(msg);
        await _tts.speak(msg);
      }
    } catch (e) {
      const errorMsg = "Atenção! Identifique-se imediatamente. Você está em uma zona restrita. Qual o motivo da sua presença?";
      _typeSubtitle(errorMsg);
      await _tts.speak(errorMsg);
    } finally {
      if (mounted) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isAlerting = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _stopCamera();
    _pulseController.dispose();
    _rotationController.dispose();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final polygonPixels = polygonNormalized.map((offset) => Offset(offset.dx * size.width, offset.dy * size.height)).toList();

          return Stack(
            fit: StackFit.expand,
            children: [
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
                bottom: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: _isSpeaking
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCyberCube(),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _isAlerting ? Colors.red : const Color(0xFF27AE60)),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isAlerting ? Colors.red : const Color(0xFF27AE60)).withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _isAlerting ? ">>> ALERTA DE INTRUSÃO <<<" : ">>> TERLINET EYES COMUNICAÇÃO <<<",
                                  style: GoogleFonts.vt323(
                                    color: _isAlerting ? Colors.red : const Color(0xFF27AE60),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Divider(color: Colors.white24),
                                Text(
                                  _subtitle,
                                  style: GoogleFonts.vt323(
                                    color: Colors.white,
                                    fontSize: 18,
                                    letterSpacing: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
                ),
              ),

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
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: _isAlerting ? Colors.red : Colors.green)),
                      child: Text(_isAlerting ? "STATUS: ALERTA!" : "STATUS: SEGURO", style: TextStyle(color: _isAlerting ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
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
    final paint = Paint()..color = const Color(0xFF27AE60)..style = PaintingStyle.fill;
    for (var lm in landmarks) {
      if (lm['visibility'] > 0.5) {
        double x = (1.0 - (lm['x'] as num).toDouble()) * size.width;
        double y = (lm['y'] as num).toDouble() * size.height;
        canvas.drawCircle(Offset(x, y), 4, paint);
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

    final fillPaint = Paint()..color = (isAlerting ? Colors.red : Colors.green).withOpacity(0.1)..style = PaintingStyle.fill;

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
