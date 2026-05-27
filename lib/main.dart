import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

// --- Ponte JS Interop ---
@JS('initPoseDetector')
external JSPromise<JSBoolean> _initPoseDetector();

@JS('startCamera')
external JSPromise<JSBoolean> _startCamera(JSString facingMode);

@JS('stopCamera')
external void _stopCamera();

@JS('setPoseCallback')
external void _setPoseCallback(JSFunction callback);

@JS('captureFrame')
external JSString _captureFrame();

@JS('downloadImage')
external void _downloadImage(JSString dataUrl, JSString filename);

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
          Container(color: Colors.black.withOpacity(0.7)),
          SingleChildScrollView(
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                  maxWidth: 1200, // Limita a largura para telas muito grandes
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.security, size: 80, color: Color(0xFF27AE60)),
                    const SizedBox(height: 20),
                    Text("TERLINET EYES",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.orbitron(
                            fontSize: clampDouble(MediaQuery.of(context).size.width * 0.05, 32, 48),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 10,
                            color: Colors.white)),
                    const Text("SISTEMA DE MONITORAMENTO COM IA",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, letterSpacing: 5)),
                    const SizedBox(height: 40),

                    // Seção de Funcionalidades
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildFeatureCard(
                            icon: Icons.psychology,
                            title: "IA AVANÇADA",
                            description: "Detecção de pose humana em tempo real processada localmente.",
                          ),
                          _buildFeatureCard(
                            icon: Icons.crop_free,
                            title: "ZONAS DINÂMICAS",
                            description: "Defina perímetros de segurança customizáveis arrastando os pontos.",
                          ),
                          _buildFeatureCard(
                            icon: Icons.campaign,
                            title: "ALERTAS VOCAIS",
                            description: "Protocolos de voz gerados por IA para dissuasão imediata.",
                          ),
                          _buildFeatureCard(
                            icon: Icons.photo_camera,
                            title: "EVIDÊNCIA DIGITAL",
                            description: "Captura automática de fotos no momento exato da invasão.",
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27AE60),
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 25),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 10,
                        shadowColor: const Color(0xFF27AE60).withOpacity(0.5),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MonitorPage()),
                        );
                      },
                      child: const Text("INICIAR SISTEMA DE ELITE",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16, letterSpacing: 2)),
                    ),
                    const SizedBox(height: 40),
                    const Text("GOVERNANCE & VISION SYSTEM V1.0",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 3)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({required IconData icon, required String title, required String description}) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF27AE60), size: 32),
          const SizedBox(height: 15),
          Text(title, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 10),
          Text(description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }

  double clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
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
  bool _isGlitching = false;
  bool _isFrontCamera = true;
  double _glitchX = 0;
  double _glitchY = 0;
  String _subtitle = "";
  String? _lastPhoto;
  bool _showFlash = false;
  Timer? _typewriterTimer;
  Timer? _glitchTimer;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  bool _isSwitchingCamera = false;
  bool _isMonitoringActive = false;
  bool _cameraError = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  DateTime _lastAlertTime = DateTime.now().subtract(const Duration(seconds: 10));

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
    await _tts.setSpeechRate(1.0); // Aumentado de 0.8 para 1.0 para fala mais rápida
    await _tts.setPitch(1.2);

    try {
      var voices = await _tts.getVoices;
      for (var voice in voices) {
        String name = voice["name"].toString().toLowerCase();
        if (name.contains("portuguese") || name.contains("brazil")) {
          if (name.contains("female") || name.contains("feminina") || name.contains("maria") || name.contains("google pt-br")) {
            await _tts.setVoice({"name": voice["name"], "locale": voice["locale"]});
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("Erro ao buscar vozes: $e");
    }

    _tts.setStartHandler(() => setState(() => _isSpeaking = true));
    _tts.setCompletionHandler(() => setState(() => _isSpeaking = false));
    _tts.setErrorHandler((msg) => setState(() => _isSpeaking = false));
  }

  Future<void> _speakIntroduction() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await http.get(
        Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/explain_system")
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final text = jsonDecode(response.body)['message'];
        _typeSubtitle(text);
        await _tts.speak(text);
        return;
      }
    } catch (e) {
      debugPrint("Erro IA Intro: $e");
    }
    const fallback = "TerlineT Eyes operacional. Ajuste o perímetro para iniciar o monitoramento de elite.";
    _typeSubtitle(fallback);
    await _tts.speak(fallback);
  }

  void _typeSubtitle(String text) {
    _typewriterTimer?.cancel();
    _glitchTimer?.cancel();
    setState(() {
      _subtitle = "";
      _isSpeaking = true;
      _isGlitching = false;
    });

    int charIndex = 0;
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (charIndex < text.length) {
        setState(() {
          _subtitle += text[charIndex];
          if (math.Random().nextDouble() < 0.1) _triggerGlitch();
        });
        charIndex++;
      } else {
        timer.cancel();
      }
    });
  }

  void _triggerGlitch() {
    setState(() {
      _isGlitching = true;
      _glitchX = (math.Random().nextDouble() - 0.5) * 10;
      _glitchY = (math.Random().nextDouble() - 0.5) * 5;
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() { _isGlitching = false; _glitchX = 0; _glitchY = 0; });
    });
  }

  Future<void> _setupPoseDetection() async {
    try {
      _setPoseCallback(_onPoseDetected.toJS);
      final initSuccess = await _initPoseDetector().toDart;
      if (initSuccess.toDart) {
        final cameraStarted = await _startCamera(_isFrontCamera ? "user".toJS : "environment".toJS).toDart;
        if (!cameraStarted.toDart) {
          setState(() => _cameraError = true);
        }
      } else {
        setState(() => _cameraError = true);
      }
    } catch (e) {
      debugPrint("Erro Setup: $e");
      setState(() => _cameraError = true);
    }
  }

  void _switchCamera() async {
    if (_isSwitchingCamera) return;
    setState(() {
      _isSwitchingCamera = true;
      _isFrontCamera = !_isFrontCamera;
      _landmarks = []; // Limpa landmarks durante a troca
    });

    try {
      await _startCamera(_isFrontCamera ? "user".toJS : "environment".toJS).toDart;
    } catch (e) {
      debugPrint("Erro ao trocar câmera: $e");
    } finally {
      if (mounted) setState(() => _isSwitchingCamera = false);
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

  void _startMonitoring() {
    if (_isMonitoringActive || _countdown > 0) return;

    setState(() {
      _countdown = 5;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdown > 1) {
          _countdown--;
          _tts.speak(_countdown.toString());
        } else {
          _countdown = 0;
          _isMonitoringActive = true;
          timer.cancel();
          _tts.speak("Sistema de monitoramento ativado. Perímetro seguro.");
          _typeSubtitle("SISTEMA DE MONITORAMENTO ATIVADO");
        }
      });
    });
  }

  void _checkInvasion(List<dynamic> landmarks) {
    if (!_isMonitoringActive || landmarks.isEmpty) return;

    bool anyPartInside = false;
    for (var lm in landmarks) {
      if (lm['visibility'] > 0.5) {
        // Se for câmera frontal, inverte o X. Se for traseira, usa direto.
        double x = _isFrontCamera ? 1.0 - (lm['x'] as num).toDouble() : (lm['x'] as num).toDouble();
        double y = (lm['y'] as num).toDouble();

        if (_isPointInPolygon(Offset(x, y), polygonNormalized)) {
          anyPartInside = true;
          break;
        }
      }
    }

    if (anyPartInside) _processAlert();
  }

  Widget _buildCyberCube() {
    final cubeColor = _isAlerting ? Colors.red : const Color(0xFF27AE60);
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _rotationController]),
      builder: (context, child) {
        final pulse = 1.0 + (_pulseController.value * 0.2);
        return Transform(
          transform: Matrix4.identity()..setEntry(3, 2, 0.002)..rotateX(_rotationController.value * 6.28)..rotateY(_rotationController.value * 6.28)..scale(pulse),
          alignment: Alignment.center,
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: cubeColor.withOpacity(0.2), border: Border.all(color: cubeColor, width: 2),
              boxShadow: [BoxShadow(color: cubeColor.withOpacity(0.5), blurRadius: 15, spreadRadius: 5)]),
            child: Center(child: Icon(_isAlerting ? Icons.warning_amber_rounded : Icons.auto_awesome, color: Colors.white.withOpacity(0.8), size: 20)),
          ),
        );
      },
    );
  }

  bool _isPointInPolygon(Offset p, List<Offset> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      if (((poly[i].dy > p.dy) != (poly[j].dy > p.dy)) && (p.dx < (poly[j].dx - poly[i].dx) * (p.dy - poly[i].dy) / (poly[j].dy - poly[i].dy) + poly[i].dx)) {
        inside = !inside;
      }
    }
    return inside;
  }

  Future<void> _processAlert() async {
    final now = DateTime.now();
    if (now.difference(_lastAlertTime).inSeconds < 8) return;
    _lastAlertTime = now;

    // Captura a foto automaticamente no momento da intrusão
    _takeAutomaticPhoto();

    setState(() => _isAlerting = true);
    try {
      final response = await http.post(Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/vision_alert"),
        body: jsonEncode({"area_name": "Perímetro Alfa", "object_type": "presença humana detectada", "severity": "high"}),
        headers: {"Content-Type": "application/json"}).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final msg = jsonDecode(response.body)['message'];
        _typeSubtitle(msg);
        await _tts.speak(msg);
      }
    } catch (e) {
      const errorMsg = "Atenção! Identifique-se imediatamente. Zona restrita.";
      _typeSubtitle(errorMsg);
      await _tts.speak(errorMsg);
    } finally {
      if (mounted) Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _isAlerting = false); });
    }
  }

  void _takeAutomaticPhoto() {
    final photoData = _captureFrame().toDart;
    if (photoData.isNotEmpty) {
      setState(() {
        _lastPhoto = photoData;
        _showFlash = true;
      });
      // Efeito de flash da câmera
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _showFlash = false);
      });
      debugPrint("Foto de intrusão capturada!");
    }
  }

  void _downloadLastPhoto() {
    if (_lastPhoto != null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _downloadImage(_lastPhoto!.toJS, "intrusao_$timestamp.jpg".toJS);
    }
  }

  @override
  void dispose() {
    _stopCamera();
    _pulseController.dispose();
    _rotationController.dispose();
    _typewriterTimer?.cancel();
    _glitchTimer?.cancel();
    _countdownTimer?.cancel();
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
              if (_landmarks.isNotEmpty) CustomPaint(painter: PosePainter(_landmarks, _isFrontCamera), size: Size.infinite),
              GestureDetector(
                onPanStart: (details) {
                  final pos = details.localPosition;
                  for (int i = 0; i < polygonPixels.length; i++) {
                    if ((pos - polygonPixels[i]).distance < 50) { setState(() => _draggingIndex = i); return; }
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
                child: CustomPaint(size: Size.infinite, painter: PolygonPainter(polygon: polygonPixels, isAlerting: _isAlerting)),
              ),
              Positioned(
                bottom: 100, left: 0, right: 0,
                child: Center(
                  child: _isSpeaking
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        _buildCyberCube(),
                        const SizedBox(height: 20),
                        Transform.translate(offset: Offset(_glitchX, _glitchY),
                          child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), margin: const EdgeInsets.symmetric(horizontal: 40), width: double.infinity,
                            decoration: BoxDecoration(color: _isGlitching ? (_isAlerting ? Colors.red.withOpacity(0.5) : const Color(0xFF27AE60).withOpacity(0.5)) : Colors.black87,
                              borderRadius: BorderRadius.circular(10), border: Border.all(color: _isAlerting ? Colors.red : const Color(0xFF27AE60), width: _isGlitching ? 4 : 1),
                              boxShadow: [BoxShadow(color: (_isAlerting ? Colors.red : const Color(0xFF27AE60)).withOpacity(0.3), blurRadius: 10, spreadRadius: 2), if (_isGlitching) BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 20, offset: const Offset(5, 0))]),
                            child: Column(children: [
                              Text(_isAlerting ? ">>> ALERTA DE INTRUSÃO <<<" : ">>> TERLINET EYES COMUNICAÇÃO <<<", style: GoogleFonts.vt323(color: _isAlerting ? Colors.red : const Color(0xFF27AE60), fontSize: 14, fontWeight: FontWeight.bold, decoration: _isGlitching ? TextDecoration.lineThrough : null)),
                              const Divider(color: Colors.white24),
                              Text(_subtitle, style: GoogleFonts.vt323(color: _isGlitching ? Colors.cyanAccent : Colors.white, fontSize: 18, letterSpacing: 1.5, shadows: _isGlitching ? [const Shadow(color: Colors.red, offset: Offset(-2, 0)), const Shadow(color: Colors.blue, offset: Offset(2, 0))] : null), textAlign: TextAlign.center),
                            ]),
                          ),
                        ),
                      ])
                    : const SizedBox.shrink(),
                ),
              ),
              Positioned(
                top: 40, left: 20, right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    Row(
                      children: [
                        if (!_isMonitoringActive && _countdown == 0)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white),
                            onPressed: _startMonitoring,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text("INICIAR MONITORAMENTO"),
                          ),
                        const SizedBox(width: 10),
                        IconButton(icon: const Icon(Icons.flip_camera_ios, color: Colors.white), onPressed: _isSwitchingCamera ? null : _switchCamera),
                      ],
                    ),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: _isAlerting ? Colors.red : (_isSwitchingCamera ? Colors.orange : (_isMonitoringActive ? Colors.green : Colors.grey)))),
                      child: Text(_isAlerting ? "STATUS: ALERTA!" : (_isSwitchingCamera ? "TROCANDO CÂMERA..." : (!_isMonitoringActive ? (_countdown > 0 ? "INICIANDO EM $_countdown..." : "STATUS: STANDBY") : "STATUS: SEGURO")), style: TextStyle(color: _isAlerting ? Colors.red : (_isSwitchingCamera ? Colors.orange : (_isMonitoringActive ? Colors.green : Colors.grey)), fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
              ),

              // Overlay de Countdown
              if (_countdown > 0)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF27AE60), width: 2)),
                    child: Text("$_countdown", style: GoogleFonts.orbitron(color: Colors.white, fontSize: 80, fontWeight: FontWeight.bold)),
                  ),
                ),

              // Thumbnail da última foto capturada
              if (_lastPhoto != null)
                Positioned(
                  top: 100, right: 20,
                  child: GestureDetector(
                    onTap: _downloadLastPhoto,
                    child: Container(
                      width: 120, height: 90,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          children: [
                            Image.network(_lastPhoto!, fit: BoxFit.cover, width: 120, height: 90),
                            Container(
                              padding: const EdgeInsets.all(4),
                              color: Colors.red,
                              child: const Text("CAPTURADO", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                            Positioned(
                              bottom: 4, right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.download, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Efeito de Flash
              if (_showFlash)
                Positioned.fill(
                  child: Container(color: Colors.white.withOpacity(0.8)),
                ),

              // Erro de Câmera
              if (_cameraError)
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_off, color: Colors.red, size: 80),
                          const SizedBox(height: 20),
                          Text("CÂMERA NÃO DETECTADA", style: GoogleFonts.orbitron(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
                          const Text(
                            "Olá! Não conseguimos acessar sua câmera. O sistema TerlineT Eyes precisa de uma visão ativa para monitorar o perímetro.\n\nPor favor, verifique se a câmera está conectada, se você deu permissão no navegador ou se outro app a está usando.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60)),
                            onPressed: () => Navigator.pop(context),
                            child: const Text("VOLTAR E TENTAR NOVAMENTE", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
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
  final bool isFrontCamera;
  PosePainter(this.landmarks, this.isFrontCamera);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF27AE60)..style = PaintingStyle.fill;
    for (var lm in landmarks) {
      if (lm['visibility'] > 0.5) {
        double x = isFrontCamera ? (1.0 - (lm['x'] as num).toDouble()) * size.width : (lm['x'] as num).toDouble() * size.width;
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
    final paint = Paint()..color = isAlerting ? Colors.red.withOpacity(0.8) : Colors.green.withOpacity(0.8)..strokeWidth = 3..style = PaintingStyle.stroke;
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
