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

@JS('openUrl')
external void _openUrl(JSString url);

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
        double x = 1.0 - (nose['x'] as num).toDouble();
        double y = (nose['y'] as num).toDouble();
        lookAt = Offset(x, y);
      }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CyberEye(lookAt: lookAt),
        const SizedBox(width: 20),
        CyberEye(lookAt: lookAt),
      ],
    );
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
                  maxWidth: 1200,
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
                          _buildCounterCard(),
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
                  "O processamento de IA ocorre exclusivamente no seu navegador. Nenhuma imagem é capturada, enviada ou armazenada em nossos servidores.",
                  style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterCard() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openUrl("https://terlinet.github.io/counter/".toJS),
        child: Container(
          width: 260,
          height: 180,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.greenAccent.withOpacity(0.1), blurRadius: 10, spreadRadius: 2),
            ],
          ),
          child: Stack(
            children: [
              const MatrixRain(),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.speed, color: Colors.greenAccent, size: 32),
                    const SizedBox(height: 10),
                    Text("COUNTER",
                        style: GoogleFonts.orbitron(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 5)),
                    const SizedBox(height: 5),
                    Text("ACESSO AO SISTEMA DE CONTAGEM",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.orbitron(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: List.generate(20, (index) => index % 2 == 0 ? Colors.transparent : Colors.black.withOpacity(0.05)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({required IconData icon, required String title, required String description, Color color = const Color(0xFF27AE60)}) {
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
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 15),
          Text(title, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 10),
          Text(description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
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
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _initTts().then((_) => _speakIntroduction());
    _setupPoseDetection();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("pt-BR");
    await _tts.setSpeechRate(1.0);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() => setState(() => _isSpeaking = true));
    _tts.setCompletionHandler(() => setState(() => _isSpeaking = false));
  }

  Future<void> _speakIntroduction() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await http.get(Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/explain_system")).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final text = jsonDecode(response.body)['message'];
        _typeSubtitle(text);
        await _tts.speak(text);
        return;
      }
    } catch (e) {}
    const fallback = "TerlineT Eyes operacional.";
    _typeSubtitle(fallback);
    await _tts.speak(fallback);
  }

  void _typeSubtitle(String text) {
    _typewriterTimer?.cancel();
    _glitchTimer?.cancel();
    setState(() { _subtitle = ""; _isSpeaking = true; _isGlitching = false; });
    int charIndex = 0;
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (charIndex < text.length) {
        setState(() { _subtitle += text[charIndex]; if (math.Random().nextDouble() < 0.1) _triggerGlitch(); });
        charIndex++;
      } else { timer.cancel(); }
    });
  }

  void _triggerGlitch() {
    setState(() { _isGlitching = true; _glitchX = (math.Random().nextDouble() - 0.5) * 10; _glitchY = (math.Random().nextDouble() - 0.5) * 5; });
    Future.delayed(const Duration(milliseconds: 50), () { if (mounted) setState(() { _isGlitching = false; _glitchX = 0; _glitchY = 0; }); });
  }

  Future<void> _setupPoseDetection() async {
    try {
      _setPoseCallback(_onPoseDetected.toJS);
      final initSuccess = await _initPoseDetector().toDart;
      if (initSuccess.toDart) {
        await _startCamera(_isFrontCamera ? "user".toJS : "environment".toJS).toDart;
      }
    } catch (e) { setState(() => _cameraError = true); }
  }

  void _switchCamera() async {
    if (_isSwitchingCamera) return;
    setState(() { _isSwitchingCamera = true; _isFrontCamera = !_isFrontCamera; _landmarks = []; });
    try { await _startCamera(_isFrontCamera ? "user".toJS : "environment".toJS).toDart; }
    finally { if (mounted) setState(() => _isSwitchingCamera = false); }
  }

  void _onPoseDetected(JSString landmarksJson) {
    if (!mounted) return;
    final List<dynamic> newLandmarks = jsonDecode(landmarksJson.toDart);
    setState(() { _landmarks = newLandmarks; });
    _checkInvasion(newLandmarks);
  }

  void _startMonitoring() {
    if (_isMonitoringActive || _countdown > 0) return;
    setState(() { _countdown = 5; });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_countdown > 1) { _countdown--; _tts.speak(_countdown.toString()); }
        else { _countdown = 0; _isMonitoringActive = true; timer.cancel(); _tts.speak("Sistema ativado."); }
      });
    });
  }

  void _checkInvasion(List<dynamic> landmarks) {
    if (!_isMonitoringActive || landmarks.isEmpty) return;
    bool anyPartInside = false;
    for (var lm in landmarks) {
      if (lm['visibility'] > 0.5) {
        double x = _isFrontCamera ? 1.0 - (lm['x'] as num).toDouble() : (lm['x'] as num).toDouble();
        double y = (lm['y'] as num).toDouble();
        if (_isPointInPolygon(Offset(x, y), polygonNormalized)) { anyPartInside = true; break; }
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
          child: Container(width: 60, height: 60, decoration: BoxDecoration(color: cubeColor.withOpacity(0.2), border: Border.all(color: cubeColor, width: 2), boxShadow: [BoxShadow(color: cubeColor.withOpacity(0.5), blurRadius: 15, spreadRadius: 5)]), child: Center(child: Icon(_isAlerting ? Icons.warning_amber_rounded : Icons.auto_awesome, color: Colors.white.withOpacity(0.8), size: 20))),
        );
      },
    );
  }

  bool _isPointInPolygon(Offset p, List<Offset> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      if (((poly[i].dy > p.dy) != (poly[j].dy > p.dy)) && (p.dx < (poly[j].dx - poly[i].dx) * (p.dy - poly[i].dy) / (poly[j].dy - poly[i].dy) + poly[i].dx)) { inside = !inside; }
    }
    return inside;
  }

  Future<void> _processAlert() async {
    final now = DateTime.now();
    if (now.difference(_lastAlertTime).inSeconds < 8) return;
    _lastAlertTime = now;
    _takeAutomaticPhoto();
    setState(() => _isAlerting = true);
    try {
      final response = await http.post(Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/vision_alert"), body: jsonEncode({"area_name": "Perímetro Alfa", "object_type": "presença humana", "severity": "high"}), headers: {"Content-Type": "application/json"}).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final msg = jsonDecode(response.body)['message'];
        _typeSubtitle(msg);
        await _tts.speak(msg);
      }
    } catch (e) {}
    finally { if (mounted) Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _isAlerting = false); }); }
  }

  void _takeAutomaticPhoto() {
    final photoData = _captureFrame().toDart;
    if (photoData.isNotEmpty) {
      setState(() { _lastPhoto = photoData; _showFlash = true; });
      Future.delayed(const Duration(milliseconds: 100), () { if (mounted) setState(() => _showFlash = false); });
    }
  }

  @override
  void dispose() { _stopCamera(); _pulseController.dispose(); _rotationController.dispose(); _typewriterTimer?.cancel(); _glitchTimer?.cancel(); _countdownTimer?.cancel(); super.dispose(); }

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
                  for (int i = 0; i < polygonPixels.length; i++) { if ((pos - polygonPixels[i]).distance < 50) { setState(() => _draggingIndex = i); return; } }
                },
                onPanUpdate: (details) {
                  if (_draggingIndex != null) { setState(() { double dx = (details.localPosition.dx / size.width).clamp(0.0, 1.0); double dy = (details.localPosition.dy / size.height).clamp(0.0, 1.0); polygonNormalized[_draggingIndex!] = Offset(dx, dy); }); }
                },
                onPanEnd: (_) => setState(() => _draggingIndex = null),
                child: CustomPaint(size: Size.infinite, painter: PolygonPainter(polygon: polygonPixels, isAlerting: _isAlerting)),
              ),
              Positioned(top: 20, left: 20, child: Column(mainAxisSize: MainAxisSize.min, children: [_buildInteractiveCube(), const SizedBox(height: 10), _buildInteractiveTieFighter()])),
              Positioned(bottom: 100, left: 0, right: 0, child: Center(child: _isSpeaking ? Column(mainAxisSize: MainAxisSize.min, children: [_buildCyberCube(), const SizedBox(height: 20), Transform.translate(offset: Offset(_glitchX, _glitchY), child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), margin: const EdgeInsets.symmetric(horizontal: 40), width: double.infinity, decoration: BoxDecoration(color: _isGlitching ? Colors.green.withOpacity(0.5) : Colors.black87, borderRadius: BorderRadius.circular(10), border: Border.all(color: _isAlerting ? Colors.red : const Color(0xFF27AE60))), child: Column(children: [Text(_isAlerting ? "ALERTA" : "COMUNICAÇÃO", style: GoogleFonts.vt323(color: _isAlerting ? Colors.red : const Color(0xFF27AE60))), const Divider(color: Colors.white24), Text(_subtitle, style: GoogleFonts.vt323(color: Colors.white, fontSize: 18), textAlign: TextAlign.center)])))]) : const SizedBox.shrink())),
              Positioned(top: 40, left: 20, right: 20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)), Row(children: [if (!_isMonitoringActive && _countdown == 0) ElevatedButton.icon(onPressed: _startMonitoring, icon: const Icon(Icons.play_arrow), label: const Text("INICIAR"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60))), const SizedBox(width: 10), IconButton(icon: const Icon(Icons.flip_camera_ios, color: Colors.white), onPressed: _isSwitchingCamera ? null : _switchCamera)]), Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: _isAlerting ? Colors.red : Colors.green)), child: Text(_isAlerting ? "ALERTA" : "SEGURO", style: const TextStyle(color: Colors.white, fontSize: 12)))]))
            ],
          );
        },
      ),
    );
  }
}

class DefensePage extends StatefulWidget {
  const DefensePage({super.key});
  @override State<DefensePage> createState() => _DefensePageState();
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
  Offset? _laserTarget;
  Timer? _laserTimer;

  List<Offset> polygonNormalized = [const Offset(0.2, 0.2), const Offset(0.8, 0.2), const Offset(0.8, 0.8), const Offset(0.2, 0.8)];
  int? _draggingIndex;

  @override
  void initState() { super.initState(); _initTts().then((_) => _speakIntro()); _setupPoseDetection(); }

  Future<void> _initTts() async { await _tts.setLanguage("pt-BR"); await _tts.setSpeechRate(1.0); await _tts.setPitch(0.9); _tts.setStartHandler(() => setState(() => _isSpeaking = true)); _tts.setCompletionHandler(() => setState(() => _isSpeaking = false)); }

  Future<void> _speakIntro() async {
    try {
      final response = await http.get(Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/defense_intro")).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) { final text = jsonDecode(response.body)['message']; setState(() => _subtitle = text); await _tts.speak(text); }
    } catch (e) {}
  }

  Future<void> _setupPoseDetection() async { try { _setPoseCallback(_onPoseDetected.toJS); final initSuccess = await _initPoseDetector().toDart; if (initSuccess.toDart) { await _startCamera(_isFrontCamera ? "user".toJS : "environment".toJS).toDart; } } catch (e) { setState(() => _cameraError = true); } }

  void _onPoseDetected(JSString landmarksJson) { if (!mounted) return; final List<dynamic> newLandmarks = jsonDecode(landmarksJson.toDart); setState(() { _landmarks = newLandmarks; }); _checkInvasion(newLandmarks); }

  void _checkInvasion(List<dynamic> landmarks) {
    if (!_isDefenseActive || landmarks.isEmpty) return;
    List<Offset> targetsInZone = [];
    for (var lm in landmarks) {
      if ((lm['visibility'] as num) > 0.1) {
        double x = _isFrontCamera ? 1.0 - (lm['x'] as num).toDouble() : (lm['x'] as num).toDouble();
        double y = (lm['y'] as num).toDouble();
        if (_isPointInPolygon(Offset(x, y), polygonNormalized)) { targetsInZone.add(Offset(x, y)); }
      }
    }
    if (targetsInZone.isNotEmpty) {
      double sumX = 0, sumY = 0; for (var p in targetsInZone) { sumX += p.dx; sumY += p.dy; }
      Offset target = Offset(sumX / targetsInZone.length, sumY / targetsInZone.length);
      setState(() { _lockOnPoint = target; }); _fireLaser(target);
    } else { setState(() => _lockOnPoint = null); }
  }

  void _fireLaser(Offset target) {
    if (!_isDefenseActive || (_laserTimer?.isActive ?? false)) return;
    setState(() { _laserTarget = target; }); _playSound("assets/laser.mp3".toJS);
    _laserTimer = Timer(const Duration(milliseconds: 300), () { if (mounted) setState(() => _laserTarget = null); });
  }

  bool _isPointInPolygon(Offset p, List<Offset> poly) { bool inside = false; for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) { if (((poly[i].dy > p.dy) != (poly[j].dy > p.dy)) && (p.dx < (poly[j].dx - poly[i].dx) * (p.dy - poly[i].dy) / (poly[j].dy - poly[i].dy) + poly[i].dx)) inside = !inside; } return inside; }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        final polygonPixels = polygonNormalized.map((offset) => Offset(offset.dx * size.width, offset.dy * size.height)).toList();
        return Stack(fit: StackFit.expand, children: [
          if (_landmarks.isNotEmpty) CustomPaint(painter: PosePainter(_landmarks, _isFrontCamera), size: Size.infinite),
          GestureDetector(
            onPanStart: (details) { for (int i = 0; i < polygonPixels.length; i++) { if ((details.localPosition - polygonPixels[i]).distance < 50) { setState(() => _draggingIndex = i); return; } } },
            onPanUpdate: (details) { if (_draggingIndex != null) { setState(() { polygonNormalized[_draggingIndex!] = Offset((details.localPosition.dx / size.width).clamp(0, 1), (details.localPosition.dy / size.height).clamp(0, 1)); }); } },
            onPanEnd: (_) => setState(() => _draggingIndex = null),
            child: CustomPaint(painter: PolygonPainter(polygon: polygonPixels, isAlerting: _lockOnPoint != null), size: Size.infinite),
          ),
          if (_laserTarget != null) CustomPaint(painter: LaserPainter(start: const Offset(70, 200), end: Offset(_laserTarget!.dx * size.width, _laserTarget!.dy * size.height)), size: Size.infinite),
          if (_lockOnPoint != null) Positioned(left: _lockOnPoint!.dx * size.width - 25, top: _lockOnPoint!.dy * size.height - 25, child: Container(width: 50, height: 50, decoration: BoxDecoration(border: Border.all(color: Colors.redAccent.withOpacity(0.5)), shape: BoxShape.circle), child: const Center(child: Icon(Icons.add, color: Colors.redAccent, size: 20)))),
          Positioned(top: 40, left: 20, right: 20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)), ElevatedButton.icon(onPressed: () => setState(() => _isDefenseActive = true), icon: const Icon(Icons.play_arrow), label: const Text("DEFESA"), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent))])),
          if (_isSpeaking && _subtitle.isNotEmpty) Positioned(bottom: 80, left: 40, right: 40, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black87, border: Border.all(color: Colors.redAccent.withOpacity(0.5))), child: Text(_subtitle, style: GoogleFonts.vt323(color: Colors.redAccent, fontSize: 20), textAlign: TextAlign.center)))
        ]);
      }),
    );
  }
}

class HelperAssistancePage extends StatefulWidget {
  const HelperAssistancePage({super.key});
  @override State<HelperAssistancePage> createState() => _HelperAssistancePageState();
}

class _HelperAssistancePageState extends State<HelperAssistancePage> with TickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  List<dynamic> _landmarks = [];
  bool _isSpeaking = false;
  String _subtitle = "";
  bool _fallDetected = false;
  bool _waitingForResponse = false;
  late AnimationController _pulseController;
  late AnimationController _rotationController;

  @override
  void initState() { super.initState(); _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true); _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(); _initTts().then((_) => _speakIntro()); _setupPoseDetection(); _setSpeechCallback(_onSpeechDetected.toJS); }

  Future<void> _initTts() async { await _tts.setLanguage("pt-BR"); _tts.setStartHandler(() => setState(() => _isSpeaking = true)); _tts.setCompletionHandler(() => setState(() => _isSpeaking = false)); }

  Future<void> _speakIntro() async { try { final response = await http.get(Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/helper_intro")).timeout(const Duration(seconds: 5)); if (response.statusCode == 200) { final text = jsonDecode(response.body)['message']; setState(() => _subtitle = text); await _tts.speak(text); } } catch (e) {} }

  Future<void> _setupPoseDetection() async { try { _setPoseCallback(_onPoseDetected.toJS); final initSuccess = await _initPoseDetector().toDart; if (initSuccess.toDart) { await _startCamera("user".toJS).toDart; } } catch (e) {} }

  void _onPoseDetected(JSString landmarksJson) { if (!mounted) return; final List<dynamic> newLandmarks = jsonDecode(landmarksJson.toDart); setState(() { _landmarks = newLandmarks; }); _monitorBehavior(newLandmarks); }

  void _onSpeechDetected(JSString text) { if (text.toDart.toLowerCase().contains("bem")) setState(() { _fallDetected = false; _waitingForResponse = false; }); }

  void _monitorBehavior(List<dynamic> landmarks) { if (landmarks.isEmpty) return; final nose = landmarks[0]; if (nose['visibility'] > 0.5 && (nose['y'] as num) > 0.8 && !_fallDetected) { setState(() { _fallDetected = true; _waitingForResponse = true; }); _tts.speak("Você está bem?"); } }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(fit: StackFit.expand, children: [
        if (_landmarks.isNotEmpty) CustomPaint(painter: PosePainter(_landmarks, true), size: Size.infinite),
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedBuilder(animation: Listenable.merge([_pulseController, _rotationController]), builder: (context, child) => Transform(transform: Matrix4.identity()..setEntry(3, 2, 0.002)..rotateX(_rotationController.value * 6.28)..rotateY(_rotationController.value * 6.28)..scale(1 + _pulseController.value * 0.2), alignment: Alignment.center, child: Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.1), border: Border.all(color: Colors.cyanAccent), boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 20)]), child: const Center(child: Text("HELPER", style: TextStyle(fontWeight: FontWeight.bold)))))),
          const SizedBox(height: 60), if (_subtitle.isNotEmpty) Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.cyanAccent)), child: Text(_subtitle, style: GoogleFonts.vt323(color: Colors.white, fontSize: 24)))
        ])),
        Positioned(top: 40, left: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)))
      ]),
    );
  }
}

class MatrixRain extends StatefulWidget {
  const MatrixRain({super.key});
  @override State<MatrixRain> createState() => _MatrixRainState();
}

class _MatrixRainState extends State<MatrixRain> with SingleTickerProviderStateMixin {
  late AnimationController _controller; final List<MatrixColumn> _columns = [];
  @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(); for (int i = 0; i < 20; i++) _columns.add(MatrixColumn(math.Random())); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _controller, builder: (context, child) { for (var col in _columns) col.update(); return CustomPaint(size: Size.infinite, painter: MatrixPainter(_columns)); });
}

class MatrixColumn {
  final math.Random random; late double x, y, speed, fontSize; late List<String> characters;
  MatrixColumn(this.random) { reset(); }
  void reset() { x = random.nextDouble(); y = -0.5; speed = 0.005 + random.nextDouble() * 0.015; fontSize = 8 + random.nextDouble() * 8; characters = List.generate(10 + random.nextInt(15), (_) => random.nextInt(10).toString()); }
  void update() { y += speed; if (y > 1.5) reset(); }
}

class MatrixPainter extends CustomPainter {
  final List<MatrixColumn> columns; MatrixPainter(this.columns);
  @override void paint(Canvas canvas, Size size) { for (var col in columns) { final x = col.x * size.width; for (int i = 0; i < col.characters.length; i++) { final y = (col.y * size.height) - (i * col.fontSize); if (y < 0 || y > size.height) continue; final opacity = (1.0 - (i / col.characters.length)).clamp(0.0, 1.0); final paint = TextPainter(text: TextSpan(text: col.characters[i], style: GoogleFonts.vt323(color: i == 0 ? Colors.white : Colors.greenAccent.withOpacity(opacity), fontSize: col.fontSize, shadows: i == 0 ? [const Shadow(color: Colors.white, blurRadius: 10)] : null)), textDirection: TextDirection.ltr); paint.layout(); paint.paint(canvas, Offset(x, y)); } } }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PosePainter extends CustomPainter {
  final List<dynamic> landmarks; final bool isFrontCamera;
  PosePainter(this.landmarks, this.isFrontCamera);
  @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = const Color(0xFF27AE60); for (var lm in landmarks) { if (lm['visibility'] > 0.5) { canvas.drawCircle(Offset(isFrontCamera ? (1.0 - (lm['x'] as num)) * size.width : (lm['x'] as num) * size.width, (lm['y'] as num) * size.height), 4, paint); } } }
  @override bool shouldRepaint(PosePainter oldDelegate) => true;
}

class PolygonPainter extends CustomPainter {
  final List<Offset> polygon; final bool isAlerting;
  PolygonPainter({required this.polygon, required this.isAlerting});
  @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = isAlerting ? Colors.red : Colors.green..strokeWidth = 3..style = PaintingStyle.stroke; final path = Path()..addPolygon(polygon, true); canvas.drawPath(path, paint); for (var point in polygon) canvas.drawCircle(point, 6, Paint()..color = isAlerting ? Colors.red : Colors.green); }
  @override bool shouldRepaint(PolygonPainter oldDelegate) => true;
}

class CyberEye extends StatefulWidget {
  final Offset lookAt; const CyberEye({super.key, required this.lookAt});
  @override State<CyberEye> createState() => _CyberEyeState();
}

class _CyberEyeState extends State<CyberEye> with TickerProviderStateMixin {
  late AnimationController _blink; late AnimationController _pupil;
  @override void initState() { super.initState(); _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 150)); _pupil = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true); _scheduleBlink(); }
  void _scheduleBlink() { Future.delayed(Duration(seconds: 3 + math.Random().nextInt(5)), () { if (mounted) { _blink.forward().then((_) { if (mounted) _blink.reverse(); }); _scheduleBlink(); } }); }
  @override Widget build(BuildContext context) {
    double dx = (widget.lookAt.dx - 0.5).clamp(-0.4, 0.4) * 60; double dy = (widget.lookAt.dy - 0.5).clamp(-0.4, 0.4) * 60;
    return Container(width: 160, height: 160, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0F172A)), child: ClipOval(child: Stack(alignment: Alignment.center, children: [
      Transform.translate(offset: Offset(dx, dy), child: Container(width: 90, height: 90, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFF2ecc71), Colors.black])))),
      AnimatedBuilder(animation: _blink, builder: (context, child) => Column(children: [Container(height: 80 * _blink.value, color: const Color(0xFF1E293B)), const Spacer(), Container(height: 80 * _blink.value, color: const Color(0xFF1E293B))]))
    ])));
  }
}

class CyberCube extends StatefulWidget {
  final Offset lookAt; final VoidCallback? onTap; const CyberCube({super.key, required this.lookAt, this.onTap});
  @override State<CyberCube> createState() => _CyberCubeState();
}

class _CyberCubeState extends State<CyberCube> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(); }
  @override Widget build(BuildContext context) => GestureDetector(onTap: widget.onTap, child: AnimatedBuilder(animation: _controller, builder: (context, child) => Transform(transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateX(_controller.value * 6.28)..rotateY(_controller.value * 3.14), alignment: Alignment.center, child: Container(width: 50, height: 50, decoration: BoxDecoration(border: Border.all(color: Colors.cyanAccent), color: Colors.cyanAccent.withOpacity(0.1))))));
}

class TieFighter extends StatefulWidget {
  final Offset lookAt; final VoidCallback? onTap; const TieFighter({super.key, required this.lookAt, this.onTap});
  @override State<TieFighter> createState() => _TieFighterState();
}

class _TieFighterState extends State<TieFighter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(); }
  @override Widget build(BuildContext context) => GestureDetector(onTap: widget.onTap, child: AnimatedBuilder(animation: _controller, builder: (context, child) => Transform(transform: Matrix4.identity()..rotateY(_controller.value * 6.28), alignment: Alignment.center, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle)))));
}

class LaserPainter extends CustomPainter {
  final Offset start, end; LaserPainter({required this.start, required this.end});
  @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = Colors.redAccent..strokeWidth = 3; canvas.drawLine(start, end, paint); canvas.drawCircle(end, 10, paint); }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

double clampDouble(double value, double min, double max) { if (value < min) return min; if (value > max) return max; return value; }
