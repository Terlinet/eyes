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

@JS('startListening')
external void _startListening();

@JS('stopListening')
external void _stopListening();

@JS('setSpeechCallback')
external void _setSpeechCallback(JSFunction callback);

@JS('playSound')
external void _playSound(JSString soundPath);

@JS('window.open')
external void _openUrl(JSString url, [JSString? target]);

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
  List<dynamic> _landmarks = [];

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
    _setupPoseDetection();
  }

  @override
  void dispose() {
    _controller.dispose();
    _stopCamera();
    super.dispose();
  }

  Future<void> _setupPoseDetection() async {
    try {
      _setPoseCallback(_onHomePoseDetected.toJS);
      final initSuccess = await _initPoseDetector().toDart;
      if (initSuccess.toDart) {
        await _startCamera("user".toJS).toDart;
      }
    } catch (e) {
      debugPrint("Erro Face Tracking Home: $e");
    }
  }

  void _onHomePoseDetected(JSString landmarksJson) {
    if (!mounted) return;
    try {
      final List<dynamic> newLandmarks = jsonDecode(landmarksJson.toDart);
      setState(() {
        _landmarks = newLandmarks;
      });
    } catch (e) {}
  }

  Widget _buildInteractiveCube() {
    Offset lookAt = const Offset(0.5, 0.5);
    if (_landmarks.isNotEmpty) {
      final nose = _landmarks[0];
      if (nose['visibility'] > 0.5) {
        double x = 1.0 - (nose['x'] as num).toDouble();
        double y = (nose['y'] as num).toDouble();
        lookAt = Offset(x, y);
      }
    }
    return CyberCube(
      lookAt: lookAt,
      onTap: () {
        _stopCamera();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HelperAssistancePage()),
        ).then((_) => _setupPoseDetection());
      },
    );
  }

  Widget _buildInteractiveTieFighter() {
    Offset lookAt = const Offset(0.5, 0.5);
    if (_landmarks.isNotEmpty) {
      final nose = _landmarks[0];
      if (nose['visibility'] > 0.5) {
        double x = 1.0 - (nose['x'] as num).toDouble();
        double y = (nose['y'] as num).toDouble();
        lookAt = Offset(x, y);
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "DEFENSE",
          style: GoogleFonts.orbitron(
            color: Colors.redAccent,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [
              Shadow(color: Colors.red.withOpacity(0.7), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(height: 5),
        TieFighter(
          lookAt: lookAt,
          onTap: () {
            _stopCamera();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DefensePage()),
            ).then((_) => _setupPoseDetection());
          },
        ),
      ],
    );
  }

  Widget _buildInteractiveEyes() {
    Offset lookAt = const Offset(0.5, 0.5);
    if (_landmarks.isNotEmpty) {
      final nose = _landmarks[0];
      if (nose['visibility'] > 0.5) {
        // Na home usamos sempre a frontal, então invertemos o X
        double x = 1.0 - (nose['x'] as num).toDouble();
        double y = (nose['y'] as num).toDouble();
        lookAt = Offset(x, y);
      }
    }
    return CyberEyes(lookAt: lookAt);
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
                    _buildInteractiveEyes(),
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
                            icon: Icons.health_and_safety,
                            title: "HELPER ASSIST",
                            color: Colors.cyanAccent,
                            description: "IA de cuidado pessoal. Detecção inteligente de quedas com resposta por voz.",
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
                          _buildFeatureCard(
                            icon: Icons.shield,
                            title: "DEFENSE",
                            color: Colors.redAccent,
                            description: "Protocolo de defesa ativa com disparos de laser automáticos.",
                          ),
                          _buildFeatureCard(
                            icon: Icons.add_chart,
                            title: "COUNTER",
                            color: Colors.orangeAccent,
                            description: "Módulo externo de contagem e estatísticas avançadas.",
                            onTap: () => _openUrl("https://terlinet.github.io/counter/".toJS, "_self".toJS),
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
                        _stopCamera();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MonitorPage()),
                        ).then((_) => _setupPoseDetection());
                      },
                      child: const Text("INICIAR SISTEMA DE ELITE",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16, letterSpacing: 2)),
                    ),
                    const SizedBox(height: 40),
                    _buildPrivacyNotice(),
                    const SizedBox(height: 20),
                    const Text("GOVERNANCE & VISION SYSTEM V1.0",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 3)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInteractiveCube(),
                const SizedBox(height: 10),
                _buildInteractiveTieFighter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF27AE60), size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PRIVACIDADE E SEGURANÇA",
                    style: GoogleFonts.orbitron(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 5),
                const Text(
                  "O processamento de IA ocorre exclusivamente no seu navegador. Nenhuma imagem é capturada, enviada ou armazenada em nossos servidores. Você tem total controle: fotos de evidência só são salvas permanentemente se você realizar o download manual.",
                  style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    Color color = const Color(0xFF27AE60),
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 15),
            Text(title, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 10),
            Text(description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
            if (onTap != null && title == "COUNTER") ...[
              const SizedBox(height: 15),
              Text(
                "CLIQUE PARA ACESSAR",
                style: GoogleFonts.orbitron(color: color, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
            if (title == "HELPER ASSIST") ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app, color: Colors.cyanAccent, size: 12),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "TOQUE NO CUBO NO CANTO SUPERIOR ESQUERDO PARA ATIVAR",
                        style: GoogleFonts.orbitron(color: Colors.cyanAccent, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (title == "DEFENSE") ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app, color: Colors.redAccent, size: 12),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "TOQUE NO CAÇA TIE ABAIXO DO HELPER PARA ATIVAR",
                            style: GoogleFonts.orbitron(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 10),
                    Text(
                      "* SIMULAÇÃO FUTURISTA INTERATIVA *",
                      style: GoogleFonts.orbitron(color: Colors.white38, fontSize: 7, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
    await _tts.setSpeechRate(1.0); // Máxima velocidade natural
    await _tts.setPitch(1.0); // Tom mais humano e equilibrado

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

  Widget _buildInteractiveCube() {
    Offset lookAt = const Offset(0.5, 0.5);
    if (_landmarks.isNotEmpty) {
      final nose = _landmarks[0];
      if (nose['visibility'] > 0.5) {
        double x = _isFrontCamera ? 1.0 - (nose['x'] as num).toDouble() : (nose['x'] as num).toDouble();
        double y = (nose['y'] as num).toDouble();
        lookAt = Offset(x, y);
      }
    }
    return CyberCube(
      lookAt: lookAt,
      onTap: () {
        _stopCamera();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HelperAssistancePage()),
        ).then((_) => _setupPoseDetection());
      },
    );
  }

  Widget _buildInteractiveTieFighter() {
    Offset lookAt = const Offset(0.5, 0.5);
    if (_landmarks.isNotEmpty) {
      final nose = _landmarks[0];
      if (nose['visibility'] > 0.5) {
        double x = _isFrontCamera ? 1.0 - (nose['x'] as num).toDouble() : (nose['x'] as num).toDouble();
        double y = (nose['y'] as num).toDouble();
        lookAt = Offset(x, y);
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "DEFENSE",
          style: GoogleFonts.orbitron(
            color: Colors.redAccent,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [
              Shadow(color: Colors.red.withOpacity(0.7), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(height: 5),
        TieFighter(
          lookAt: lookAt,
          onTap: () {
            _stopCamera();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DefensePage()),
            ).then((_) => _setupPoseDetection());
          },
        ),
      ],
    );
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
                top: 20,
                left: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInteractiveCube(),
                    const SizedBox(height: 10),
                    _buildInteractiveTieFighter(),
                  ],
                ),
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

enum EyeEmotion { neutral, happy, angry, surprised, suspicious }

class CyberEyes extends StatefulWidget {
  final Offset lookAt;
  const CyberEyes({super.key, required this.lookAt});

  @override
  State<CyberEyes> createState() => _CyberEyesState();
}

class _CyberEyesState extends State<CyberEyes> with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _pupilController;
  late AnimationController _emotionController;
  EyeEmotion _currentEmotion = EyeEmotion.neutral;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _pupilController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _emotionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _scheduleNextBlink();
    _scheduleNextEmotion();
  }

  void _scheduleNextBlink() {
    Future.delayed(Duration(seconds: 3 + _random.nextInt(5)), () {
      if (mounted) {
        _blinkController.forward().then((_) {
          if (mounted) _blinkController.reverse();
        });
        _scheduleNextBlink();
      }
    });
  }

  void _scheduleNextEmotion() {
    Future.delayed(Duration(seconds: 5 + _random.nextInt(10)), () {
      if (mounted) {
        final nextEmotion = EyeEmotion.values[_random.nextInt(EyeEmotion.values.length)];
        setState(() => _currentEmotion = nextEmotion);
        _emotionController.forward(from: 0).then((_) {
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) {
              _emotionController.reverse().then((_) {
                if (mounted) setState(() => _currentEmotion = EyeEmotion.neutral);
              });
            }
          });
        });
        _scheduleNextEmotion();
      }
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _pupilController.dispose();
    _emotionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CyberEye(
          isLeft: true,
          lookAt: widget.lookAt,
          blinkController: _blinkController,
          pupilController: _pupilController,
          emotionController: _emotionController,
          currentEmotion: _currentEmotion,
        ),
        const SizedBox(width: 30),
        CyberEye(
          isLeft: false,
          lookAt: widget.lookAt,
          blinkController: _blinkController,
          pupilController: _pupilController,
          emotionController: _emotionController,
          currentEmotion: _currentEmotion,
        ),
      ],
    );
  }
}

class CyberEye extends StatelessWidget {
  final bool isLeft;
  final Offset lookAt;
  final AnimationController blinkController;
  final AnimationController pupilController;
  final AnimationController emotionController;
  final EyeEmotion currentEmotion;

  const CyberEye({
    super.key,
    required this.isLeft,
    required this.lookAt,
    required this.blinkController,
    required this.pupilController,
    required this.emotionController,
    required this.currentEmotion,
  });

  @override
  Widget build(BuildContext context) {
    double dx = (lookAt.dx - 0.5).clamp(-0.4, 0.4) * 60;
    double dy = (lookAt.dy - 0.5).clamp(-0.4, 0.4) * 60;

    return Container(
      width: 160, height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: const Color(0xFF27AE60).withOpacity(0.1), blurRadius: 30, spreadRadius: 5)],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(color: const Color(0xFF0F172A)),
            // Íris e Pupila
            Transform(
              transform: Matrix4.identity()..setEntry(3, 2, 0.002)..rotateY(dx * 0.005)..rotateX(-dy * 0.005)..translate(dx, dy),
              child: AnimatedBuilder(
                animation: pupilController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Íris Maior (Aumentada de 90 para 115)
                      Container(
                        width: 115, height: 115,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFF55efc4), Color(0xFF27AE60), Colors.black],
                            stops: [0.2, 0.7, 1.0]
                          ),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF27AE60).withOpacity(0.3), blurRadius: 10, spreadRadius: 2)
                          ],
                        ),
                      ),
                      // Pupila Dinâmica
                      Container(
                        width: 40 + (8 * pupilController.value),
                        height: 40 + (8 * pupilController.value),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                      ),
                      // Brilho de Vida (Catchlight Principal)
                      Positioned(
                        top: 25, left: 30,
                        child: Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                      // Brilho Secundário (Sparkle de Carisma)
                      Positioned(
                        bottom: 35, right: 35,
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Pálpebras Animadas
            AnimatedBuilder(
              animation: Listenable.merge([blinkController, emotionController]),
              builder: (context, child) {
                double val = emotionController.value;
                double topEyelidHeight = 0;
                double bottomEyelidHeight = 0;
                double topRotation = 0;
                double eyeScale = 1.0;

                switch (currentEmotion) {
                  case EyeEmotion.happy:
                    bottomEyelidHeight = 50 * val;
                    break;
                  case EyeEmotion.angry:
                    topEyelidHeight = 45 * val;
                    // Inverte a inclinação entre olho esquerdo e direito
                    topRotation = (isLeft ? 0.25 : -0.25) * val;
                    bottomEyelidHeight = 20 * val;
                    break;
                  case EyeEmotion.surprised:
                    eyeScale = 1.0 + (0.15 * val);
                    break;
                  case EyeEmotion.suspicious:
                    topEyelidHeight = 40 * val;
                    bottomEyelidHeight = 40 * val;
                    break;
                  default: break;
                }

                if (blinkController.value > 0) {
                  topEyelidHeight = 80 * blinkController.value;
                  bottomEyelidHeight = 80 * blinkController.value;
                  topRotation = 0;
                }

                return Transform.scale(
                  scale: eyeScale,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Transform.rotate(
                          angle: topRotation,
                          child: Container(
                            height: (80 * blinkController.value + topEyelidHeight).clamp(0.0, 80.0),
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: (80 * blinkController.value + bottomEyelidHeight).clamp(0.0, 80.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(currentEmotion == EyeEmotion.happy ? 100 * val : 0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class EyeHUDPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF27AE60).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Círculo tracejado externo
    for (var i = 0; i < 360; i += 20) {
      double startAngle = i * math.pi / 180;
      double sweepAngle = 10 * math.pi / 180;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 5),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    // Detalhes angulares
    paint.strokeWidth = 3;
    for (var i = 0; i < 4; i++) {
      double angle = i * math.pi / 2;
      canvas.drawLine(
        Offset(center.dx + math.cos(angle) * (radius - 15), center.dy + math.sin(angle) * (radius - 15)),
        Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DefensePage extends StatefulWidget {
  const DefensePage({super.key});

  @override
  State<DefensePage> createState() => _DefensePageState();
}

class _DefensePageState extends State<DefensePage> with TickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  List<dynamic> _landmarks = [];
  bool _isSpeaking = false;
  String _subtitle = "";
  bool _cameraError = false;
  bool _isFrontCamera = true;
  bool _isSwitchingCamera = false;
  bool _isDefenseActive = false;
  Offset? _lockOnPoint;

  List<Offset> polygonNormalized = [
    const Offset(0.2, 0.2), const Offset(0.8, 0.2),
    const Offset(0.8, 0.8), const Offset(0.2, 0.8),
  ];
  int? _draggingIndex;

  // Laser Logic
  Offset? _laserTarget;
  Timer? _laserTimer;

  @override
  void initState() {
    super.initState();
    _initTts().then((_) => _speakIntro());
    _setupPoseDetection();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("pt-BR");
    await _tts.setSpeechRate(1.0);
    await _tts.setPitch(0.9); // Voz mais grave e autoritária para defesa
    _tts.setStartHandler(() => setState(() => _isSpeaking = true));
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _subtitle = ""; // Limpa o texto ao terminar de falar para o card sumir
        });
      }
    });
    _tts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _subtitle = "";
        });
      }
    });
  }

  Future<void> _speakIntro() async {
    await Future.delayed(const Duration(seconds: 1));
    try {
      final response = await http.get(
        Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/defense_intro")
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final text = jsonDecode(response.body)['message'];
        setState(() => _subtitle = text);
        await _tts.speak(text);
        return;
      }
    } catch (e) {
      debugPrint("Erro IA Defense Intro: $e");
    }
    const text = "TerlineT operacional. Sistema de defesa ativo. Mira calibrada para neutralização de alvos humanoides de alto risco. "
                 "Qualquer presença humanoide detectada no perímetro será eliminada com precisão máxima. "
                 "Ajuste a zona de exclusão agora.";
    setState(() => _subtitle = text);
    await _tts.speak(text);
  }

  Future<void> _setupPoseDetection() async {
    try {
      _setPoseCallback(_onPoseDetected.toJS);
      final initSuccess = await _initPoseDetector().toDart;
      if (initSuccess.toDart) {
        final cameraStarted = await _startCamera(_isFrontCamera ? "user".toJS : "environment".toJS).toDart;
        if (!cameraStarted.toDart) setState(() => _cameraError = true);
      } else {
        setState(() => _cameraError = true);
      }
    } catch (e) {
      setState(() => _cameraError = true);
    }
  }

  void _switchCamera() async {
    if (_isSwitchingCamera) return;
    setState(() {
      _isSwitchingCamera = true;
      _isFrontCamera = !_isFrontCamera;
      _landmarks = [];
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

  void _startDefense() {
    setState(() {
      _isDefenseActive = true;
      _subtitle = "PROTOCOLO DE DEFESA INICIADO. PERÍMETRO PROTEGIDO.";
    });
    _tts.speak("Sistema de defesa ativado. Iniciando neutralização de alvos.");
  }

  void _checkInvasion(List<dynamic> landmarks) {
    if (!_isDefenseActive || landmarks.isEmpty) return;

    // Sensibilidade máxima: detecta qualquer parte do corpo (cabeça, braço, perna)
    // com visibilidade mínima (0.1) que entre no perímetro.
    List<Offset> targetsInZone = [];
    for (var lm in landmarks) {
      if ((lm['visibility'] as num) > 0.1) {
        double x = _isFrontCamera ? 1.0 - (lm['x'] as num).toDouble() : (lm['x'] as num).toDouble();
        double y = (lm['y'] as num).toDouble();
        Offset p = Offset(x, y);

        if (_isPointInPolygon(p, polygonNormalized)) {
          targetsInZone.add(p);
        }
      }
    }

    if (targetsInZone.isNotEmpty) {
      // Calcula o centro de massa de todas as partes do corpo detectadas na zona
      double sumX = 0, sumY = 0;
      for (var p in targetsInZone) {
        sumX += p.dx;
        sumY += p.dy;
      }
      Offset target = Offset(sumX / targetsInZone.length, sumY / targetsInZone.length);

      setState(() {
        _lockOnPoint = target;
      });
      _fireLaser(target);
    } else {
      if (_lockOnPoint != null) {
        setState(() => _lockOnPoint = null);
      }
    }
  }

  void _fireLaser(Offset targetNormalized) {
    if (!_isDefenseActive || (_laserTimer?.isActive ?? false)) return;

    setState(() {
      _laserTarget = targetNormalized;
    });

    // Som do laser disparado
    _playSound("assets/laser.mp3".toJS);

    // Tempo de recarga curto para permitir rastreamento contínuo (300ms)
    _laserTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _laserTarget = null);
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

  @override
  void dispose() {
    _stopCamera();
    _laserTimer?.cancel();
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

              // Polígono de Defesa
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
                child: CustomPaint(size: Size.infinite, painter: PolygonPainter(polygon: polygonPixels, isAlerting: _lockOnPoint != null)),
              ),

              // Laser Visual
              if (_laserTarget != null)
                CustomPaint(
                  size: Size.infinite,
                  painter: LaserPainter(
                    start: const Offset(70, 200), // Alinhado com o TieFighter tático
                    end: Offset(_laserTarget!.dx * size.width, _laserTarget!.dy * size.height),
                  ),
                ),

              // Mira de Travamento (Lock-on)
              if (_lockOnPoint != null)
                Positioned(
                  left: _lockOnPoint!.dx * size.width - 25,
                  top: _lockOnPoint!.dy * size.height - 25,
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(width: 10, height: 2, color: Colors.redAccent),
                        Container(width: 2, height: 10, color: Colors.redAccent),
                      ],
                    ),
                  ),
                ),

              // HUD de Defesa
              Positioned(
                top: 40, left: 20, right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
                    Row(
                      children: [
                        if (!_isDefenseActive)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            onPressed: _startDefense,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text("INICIAR DEFESA"),
                          ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                          onPressed: _isSwitchingCamera ? null : _switchCamera,
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isDefenseActive ? Colors.red.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: _isDefenseActive ? Colors.redAccent : Colors.grey, width: 2),
                      ),
                      child: Row(
                        children: [
                          Icon(_isDefenseActive ? Icons.gpp_maybe : Icons.shield_outlined, color: _isDefenseActive ? Colors.redAccent : Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            _isDefenseActive ? "PROTOCOLO DE DEFESA ATIVO" : "SISTEMA EM ESPERA",
                            style: GoogleFonts.orbitron(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Legendas de IA
              Positioned(
                bottom: 80, left: 40, right: 40,
                child: (_isSpeaking && _subtitle.isNotEmpty) ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.vt323(color: Colors.redAccent, fontSize: 20),
                  ),
                ) : const SizedBox.shrink(),
              ),

              if (_cameraError)
                Container(color: Colors.black, child: const Center(child: Text("ERRO CRÍTICO: CÂMERA OFFLINE", style: TextStyle(color: Colors.red)))),
            ],
          );
        },
      ),
    );
  }
}

class LaserPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  LaserPainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final innerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;

    canvas.drawLine(start, end, paint);
    canvas.drawLine(start, end, innerPaint);

    // Efeito de impacto
    canvas.drawCircle(end, 10, paint);
    canvas.drawCircle(end, 5, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CyberCube extends StatefulWidget {
  final Offset lookAt;
  final VoidCallback? onTap;
  const CyberCube({super.key, required this.lookAt, this.onTap});

  @override
  State<CyberCube> createState() => _CyberCubeState();
}

class _CyberCubeState extends State<CyberCube> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<StardustParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Inicializa algumas partículas
    for (int i = 0; i < 20; i++) {
      _particles.add(StardustParticle(_random));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateParticles() {
    for (var particle in _particles) {
      particle.update();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sensibilidade do olhar adjusted para o cubo
    double rx = (widget.lookAt.dy - 0.5) * 1.5;
    double ry = (widget.lookAt.dx - 0.5) * 1.5;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          _updateParticles();
          final angle = _controller.value * 2 * math.pi;
          return SizedBox(
            width: 120, // Aumentado para caber as partículas
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Partículas de Pó Estelar
                CustomPaint(
                  size: const Size(120, 120),
                  painter: StardustPainter(_particles),
                ),

                // Camadas de planos rotativos inspirados na imagem
                _buildPlane(angle, rx, ry, Colors.cyanAccent, 0),
                _buildPlane(angle + (math.pi / 3), rx, ry, Colors.blueAccent, 1),
                _buildPlane(angle + (2 * math.pi / 3), rx, ry, const Color(0xFF27AE60), 2),

                // Centro luminoso (Helper)
                Text(
                  "HELPER",
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(color: Colors.cyanAccent.withOpacity(0.8), blurRadius: 10),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlane(double angle, double rx, double ry, Color color, int index) {
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(angle + rx)
        ..rotateY(angle * 0.5 + ry)
        ..rotateZ(angle * 0.2),
      alignment: Alignment.center,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          border: Border.all(color: color.withOpacity(0.6), width: 1.2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}

class StardustParticle {
  late double x, y, vx, vy, life, size;
  final math.Random random;

  StardustParticle(this.random) {
    reset();
  }

  void reset() {
    x = 0; // Centralizado no cubo
    y = 0;
    double angle = random.nextDouble() * 2 * math.pi;
    double speed = random.nextDouble() * 0.5 + 0.2;
    vx = math.cos(angle) * speed;
    vy = math.sin(angle) * speed;
    life = 1.0;
    size = random.nextDouble() * 2 + 1;
  }

  void update() {
    x += vx;
    y += vy;
    life -= 0.01;
    if (life <= 0) reset();
  }
}

class StardustPainter extends CustomPainter {
  final List<StardustParticle> particles;
  StardustPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var p in particles) {
      final paint = Paint()
        ..color = Colors.cyanAccent.withOpacity(p.life)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawCircle(center + Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TieFighter extends StatefulWidget {
  final Offset lookAt;
  final VoidCallback? onTap;
  const TieFighter({super.key, required this.lookAt, this.onTap});

  @override
  State<TieFighter> createState() => _TieFighterState();
}

class _TieFighterState extends State<TieFighter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double rx = (widget.lookAt.dy - 0.5) * 1.5;
    double ry = (widget.lookAt.dx - 0.5) * 1.5;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final rotation = _controller.value * 2 * math.pi;
          return SizedBox(
            width: 100,
            height: 100,
            child: Center(
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(rx)
                  ..rotateY(rotation + ry),
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Asa Esquerda
                    Transform(
                      transform: Matrix4.identity()..translate(-35.0, 0.0, 0.0),
                      child: _buildWing(),
                    ),
                    // Asa Direita
                    Transform(
                      transform: Matrix4.identity()..translate(35.0, 0.0, 0.0),
                      child: _buildWing(),
                    ),
                    // Conexão Central
                    Container(
                      width: 70,
                      height: 4,
                      color: Colors.grey[700],
                    ),
                    // Cabine (Esfera)
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[800],
                        border: Border.all(color: Colors.grey[600]!, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 1),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.5),
                            border: Border.all(color: Colors.redAccent, width: 1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWing() {
    return Transform(
      transform: Matrix4.identity()..rotateY(math.pi / 2),
      alignment: Alignment.center,
      child: Container(
        width: 60,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.grey[700]!, width: 2),
        ),
        child: CustomPaint(
          painter: WingPatternPainter(),
        ),
      ),
    );
  }
}

class WingPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    // Linhas radiais
    for (int i = 0; i < 6; i++) {
      double angle = i * math.pi / 3;
      canvas.drawLine(
        center,
        Offset(center.dx + math.cos(angle) * size.width, center.dy + math.sin(angle) * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HelperAssistancePage extends StatefulWidget {
  const HelperAssistancePage({super.key});

  @override
  State<HelperAssistancePage> createState() => _HelperAssistancePageState();
}

class _HelperAssistancePageState extends State<HelperAssistancePage> with TickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  List<dynamic> _landmarks = [];
  bool _isSpeaking = false;
  String _subtitle = "";
  bool _cameraError = false;
  bool _isFrontCamera = true;
  bool _isSwitchingCamera = false;

  // Lógica de Assistência
  bool _fallDetected = false;
  bool _waitingForResponse = false;
  bool _callingHelp = false;
  Timer? _responseTimer;
  Timer? _alarmTimer;
  late AnimationController _pulseController;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _initTts().then((_) => _speakIntro());
    _setupPoseDetection();
    _setSpeechCallback(_onSpeechDetected.toJS);
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("pt-BR");
    await _tts.setSpeechRate(1.0); // Aumentado para dar mais energia
    await _tts.setPitch(1.0); // Tom mais humano e equilibrado

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

  Future<void> _speakIntro() async {
    await Future.delayed(const Duration(seconds: 1));
    try {
      final response = await http.get(
        Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/helper_intro")
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final text = jsonDecode(response.body)['message'];
        setState(() => _subtitle = text);
        await _tts.speak(text);
        return;
      }
    } catch (e) {
      debugPrint("Erro IA Helper Intro: $e");
    }
    const text = "Olá. Eu sou o seu Helper TerlineT. Estou monitorando o ambiente para garantir sua segurança. Caso precise de algo, estou aqui.";
    setState(() => _subtitle = text);
    await _tts.speak(text);
  }

  Future<void> _setupPoseDetection() async {
    try {
      _setPoseCallback(_onPoseDetected.toJS);
      final initSuccess = await _initPoseDetector().toDart;
      if (initSuccess.toDart) {
        final cameraStarted = await _startCamera(_isFrontCamera ? "user".toJS : "environment".toJS).toDart;
        if (!cameraStarted.toDart) setState(() => _cameraError = true);
      } else {
        setState(() => _cameraError = true);
      }
    } catch (e) {
      setState(() => _cameraError = true);
    }
  }

  void _switchCamera() async {
    if (_isSwitchingCamera) return;
    setState(() {
      _isSwitchingCamera = true;
      _isFrontCamera = !_isFrontCamera;
      _landmarks = [];
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
    _monitorBehavior(newLandmarks);
  }

  void _onSpeechDetected(JSString text) {
    if (!mounted || !_waitingForResponse) return;
    String speechText = text.toDart.toLowerCase();
    debugPrint("IA Helper ouviu: $speechText");

    if (speechText.contains("bem") ||
        speechText.contains("estou") ||
        speechText.contains("okay") ||
        speechText.contains("não precisa") ||
        speechText.contains("tudo certo")) {
      _cancelAssistance();
    }
  }

  void _monitorBehavior(List<dynamic> landmarks) {
    if (_callingHelp || landmarks.isEmpty) return;

    // Heurística simplificada de queda/mal-estar:
    // Se o nariz (index 0) estiver muito baixo na tela (Y > 0.8)
    final nose = landmarks[0];
    if (nose['visibility'] > 0.5) {
      double ny = (nose['y'] as num).toDouble();

      if (ny > 0.8 && !_fallDetected) {
        _handlePossibleFall();
      } else if (ny < 0.6 && _fallDetected) {
        _cancelAssistance();
      }
    }
  }

  void _handlePossibleFall() {
    if (_waitingForResponse) return;
    setState(() {
      _fallDetected = true;
      _waitingForResponse = true;
      _subtitle = "VERIFICANDO ESTADO...";
    });

    _processHelperCheck();
    _startListening();

    _responseTimer?.cancel();
    _responseTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _waitingForResponse) {
        _triggerAlarm();
      }
    });
  }

  Future<void> _processHelperCheck() async {
    try {
      final response = await http.post(
        Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/helper_check"),
        body: jsonEncode({"event_type": "fall_detection"}),
        headers: {"Content-Type": "application/json"}
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final msg = jsonDecode(response.body)['message'];
        setState(() => _subtitle = msg);
        await _tts.speak(msg);
        return;
      }
    } catch (e) {
      debugPrint("Erro IA Helper Check: $e");
    }
    const fallback = "Você está bem? Percebi um movimento atípico. Precisa de ajuda?";
    setState(() => _subtitle = fallback);
    await _tts.speak(fallback);
  }

  void _cancelAssistance() {
    _responseTimer?.cancel();
    _alarmTimer?.cancel();
    _stopListening();
    setState(() {
      _fallDetected = false;
      _waitingForResponse = false;
      _callingHelp = false;
      _subtitle = "SISTEMA MONITORANDO. VOCÊ PARECE ESTAR BEM.";
    });
    _tts.speak("Fico feliz que você esteja bem. Continuo monitorando.");
  }

  void _triggerAlarm() {
    _stopListening();
    setState(() {
      _waitingForResponse = false;
      _callingHelp = true;
      _subtitle = "INICIANDO PROTOCOLO DE EMERGÊNCIA...";
    });

    _processEmergencyAlert();

    _alarmTimer?.cancel();
    _alarmTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _tts.speak("ALERTA! EMERGÊNCIA! AJUDA NECESSÁRIA NESTE LOCAL!");
    });
  }

  Future<void> _processEmergencyAlert() async {
    try {
      final response = await http.get(
        Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/helper_emergency")
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final msg = jsonDecode(response.body)['message'];
        setState(() => _subtitle = msg);
        await _tts.speak(msg);
        return;
      }
    } catch (e) {
      debugPrint("Erro IA Helper Emergency: $e");
    }
    const errorMsg = "Atenção! Nenhuma resposta detectada. Iniciando protocolo de emergência e chamando ajuda agora.";
    setState(() => _subtitle = errorMsg);
    await _tts.speak(errorMsg);
  }

  Widget _buildHelperCube() {
    final cubeColor = _callingHelp ? Colors.red : (_waitingForResponse ? Colors.orange : Colors.cyanAccent);
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _rotationController]),
      builder: (context, child) {
        final pulse = 1.0 + (_pulseController.value * 0.3);
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(_rotationController.value * 6.28)
            ..rotateY(_rotationController.value * 6.28)
            ..scale(pulse),
          alignment: Alignment.center,
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: cubeColor.withOpacity(0.1),
              border: Border.all(color: cubeColor, width: 2),
              boxShadow: [BoxShadow(color: cubeColor.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)],
            ),
            child: Center(
              child: Text("HELPER", style: GoogleFonts.orbitron(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _stopCamera();
    _stopListening();
    _responseTimer?.cancel();
    _alarmTimer?.cancel();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_landmarks.isNotEmpty) CustomPaint(painter: PosePainter(_landmarks, _isFrontCamera), size: Size.infinite),

          // HUD de Monitoramento
          Positioned(
            top: 40, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _callingHelp ? Colors.red : Colors.cyanAccent),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security, color: _callingHelp ? Colors.red : Colors.cyanAccent, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        _callingHelp ? "PROTOCOLO DE EMERGÊNCIA" : "IA HELPER ATIVA",
                        style: GoogleFonts.orbitron(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48), // Spacer
              ],
            ),
          ),

          // Central Helper e Legendas
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHelperCube(),
                const SizedBox(height: 60),
                if (_subtitle.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: _callingHelp ? Colors.red : Colors.cyanAccent.withOpacity(0.5)),
                      boxShadow: [BoxShadow(color: (_callingHelp ? Colors.red : Colors.cyanAccent).withOpacity(0.2), blurRadius: 15)],
                    ),
                    child: Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.vt323(color: Colors.white, fontSize: 24, letterSpacing: 1.2),
                    ),
                  ),
              ],
            ),
          ),

          // Efeito visual de Alerta
          if (_callingHelp)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.withOpacity(_pulseController.value), width: 20),
                    ),
                  );
                },
              ),
            ),

          if (_cameraError)
             Container(
               color: Colors.black,
               child: Center(
                 child: Text("ERRO AO ACESSAR CÂMERA", style: TextStyle(color: Colors.red)),
               ),
             ),
        ],
      ),
    );
  }
}