import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui';
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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isError = false;
  List<dynamic> _landmarks = [];
  EyeEmotion _detectedEmotion = EyeEmotion.neutral;
  bool _isChatting = false;
  bool _isSpeaking = false;
  String _chatStatus = "";
  Timer? _chatTimer;
  late AnimationController _micController;
  Offset _cursorLookAt = const Offset(0.5, 0.5);
  DateTime _lastMirrorReaction = DateTime.now().subtract(const Duration(seconds: 10));
  EyeEmotion _lastMirroredEmotion = EyeEmotion.neutral;

  @override
  void initState() {
    super.initState();
    _micController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
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
    _micController.dispose();
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
        _analyzeUserEmotion(newLandmarks);
      });
    } catch (e) {}
  }

  void _startVoiceInteraction() {
    if (_isChatting) return;
    _setSpeechCallback(_onVoiceCommandDetected.toJS);
    _startListening();
    setState(() {
      _isChatting = true;
      _chatStatus = "ESTOU OUVINDO... FALE AGORA";
    });
  }

  void _onVoiceCommandDetected(JSString text) async {
    String query = text.toDart;
    if (query.isEmpty) return;

    _stopListening();
    setState(() {
      _chatStatus = "PROCESSANDO PENSAMENTO...";
      _detectedEmotion = EyeEmotion.thinking;
    });

    try {
      final response = await http.post(
        Uri.parse("https://tertulianoshow-terlinet-eyes.hf.space/ask"),
        body: jsonEncode({"question": query}),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiMessage = data['message'] ?? "";
        final emotionStr = (data['emotion'] as String?)?.toLowerCase() ?? "happy";

        // Mapeia a string de emoção retornada pela IA para o enum EyeEmotion
        EyeEmotion targetEmotion = EyeEmotion.happy;
        switch (emotionStr) {
          case 'love':
            targetEmotion = EyeEmotion.love;
            break;
          case 'excited':
            targetEmotion = EyeEmotion.excited;
            break;
          case 'surprised':
            targetEmotion = EyeEmotion.surprised;
            break;
          case 'sad':
            targetEmotion = EyeEmotion.sad;
            break;
          case 'angry':
            targetEmotion = EyeEmotion.angry;
            break;
          case 'suspicious':
            targetEmotion = EyeEmotion.suspicious;
            break;
          case 'silly':
            targetEmotion = EyeEmotion.silly;
            break;
          case 'thinking':
            targetEmotion = EyeEmotion.thinking;
            break;
          default:
            targetEmotion = EyeEmotion.happy;
        }

        setState(() {
          _chatStatus = aiMessage;
          _detectedEmotion = targetEmotion;
          _isSpeaking = true;
        });

        // Usa o seu endpoint de voz super natural do servidor
        final ttsUrl = "https://tertulianoshow-terlinet-eyes.hf.space/tts?text=${Uri.encodeComponent(aiMessage)}";
        _playSound(ttsUrl.toJS);

        // Estima o tempo de fala baseado no tamanho do texto
        final int speechDuration = math.max(2000, ((aiMessage as String).length * 90));

        _chatTimer?.cancel();
        _chatTimer = Timer(Duration(milliseconds: speechDuration), () {
          if (mounted) {
            setState(() {
              _isSpeaking = false;
              // Mantém a expressão viva um pouco mais e depois relaxa
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted && !_isSpeaking) {
                  setState(() => _detectedEmotion = EyeEmotion.neutral);
                }
              });
            });
          }
        });

        // Timer de reset total da interface de chat
        Timer(Duration(milliseconds: speechDuration + 6000), () {
          if (mounted) setState(() { _isChatting = false; _chatStatus = ""; });
        });
      }
    } catch (e) {
      setState(() {
        _chatStatus = "CONEXÃO INSTÁVEL...";
        _detectedEmotion = EyeEmotion.sad;
      });
      Future.delayed(const Duration(seconds: 2), () => setState(() => _isChatting = false));
    }
  }

  void _analyzeUserEmotion(List<dynamic> landmarks) {
    if (landmarks.length < 11 || _isSpeaking) return;

    final nose = landmarks[0];
    final leftEye = landmarks[2];
    final rightEye = landmarks[5];
    final leftMouth = landmarks[9];
    final rightMouth = landmarks[10];

    if (nose['visibility'] < 0.4 || leftMouth['visibility'] < 0.4 || rightMouth['visibility'] < 0.4) return;

    final double noseX = (nose['x'] as num).toDouble();
    final double noseY = (nose['y'] as num).toDouble();
    final double leftMouthX = (leftMouth['x'] as num).toDouble();
    final double leftMouthY = (leftMouth['y'] as num).toDouble();
    final double rightMouthX = (rightMouth['x'] as num).toDouble();
    final double rightMouthY = (rightMouth['y'] as num).toDouble();

    final double mouthCenterX = (leftMouthX + rightMouthX) / 2.0;
    final double mouthCenterY = (leftMouthY + rightMouthY) / 2.0;
    final double mouthWidth = (leftMouthX - rightMouthX).abs();
    final double mouthToNoseDist = (mouthCenterY - noseY).abs();

    // Distância dos olhos se disponível para normalização de escala facial
    double eyeDist = 0.12;
    if (landmarks.length > 5 && leftEye['visibility'] > 0.4 && rightEye['visibility'] > 0.4) {
      eyeDist = math.max(0.04, ((leftEye['x'] as num).toDouble() - (rightEye['x'] as num).toDouble()).abs());
    }

    // Normaliza largura da boca em relação à distância interocular
    final double normalizedMouthWidth = mouthWidth / eyeDist;

    // Detecção de mão próxima da boca (gesto de beijo / coração / mãozinha)
    bool handNearMouth = false;
    if (landmarks.length > 20) {
      final leftWrist = landmarks[15];
      final rightWrist = landmarks[16];
      if (leftWrist['visibility'] > 0.4) {
        final double dist = math.sqrt(math.pow((leftWrist['x'] as num).toDouble() - mouthCenterX, 2) + math.pow((leftWrist['y'] as num).toDouble() - mouthCenterY, 2));
        if (dist < 0.15) handNearMouth = true;
      }
      if (rightWrist['visibility'] > 0.4) {
        final double dist = math.sqrt(math.pow((rightWrist['x'] as num).toDouble() - mouthCenterX, 2) + math.pow((rightWrist['y'] as num).toDouble() - mouthCenterY, 2));
        if (dist < 0.15) handNearMouth = true;
      }
    }

    EyeEmotion targetEmotion = EyeEmotion.neutral;
    String feedbackText = "";

    // 1. BEIJO (boca em bico estreita E mãos perto da boca ou boca bem compacta projetada)
    if (handNearMouth || (normalizedMouthWidth < 0.45 && mouthToNoseDist < 0.14)) {
      targetEmotion = EyeEmotion.love;
      feedbackText = "♥ MANDOU UM BEIJO! BEIJINHO DE VOLTA!";
    }
    // 2. SORRISO (boca larga puxada para as laterais)
    else if (normalizedMouthWidth > 0.75 || mouthWidth > 0.082) {
      targetEmotion = EyeEmotion.happy;
      feedbackText = "😄 VI SEU SORRISO! SORRINDO COM VOCÊ!";
    }
    // 3. SURPRESA / BOCA ABERTA (distância boca-nariz acentuada e boca aberta em 'O')
    else if (mouthToNoseDist > 0.135) {
      targetEmotion = EyeEmotion.surprised;
      feedbackText = "😲 OPA! VOCÊ FICOU SURPRESO?!";
    }
    // 4. TRISTEZA / BOCA CAÍDA
    else if (mouthCenterY > noseY + 0.11 && normalizedMouthWidth < 0.58) {
      targetEmotion = EyeEmotion.sad;
      feedbackText = "🥺 NÃO FIQUE TRISTE, ESTOU AQUI!";
    }

    if (targetEmotion != EyeEmotion.neutral && targetEmotion != _detectedEmotion) {
      final now = DateTime.now();
      setState(() {
        _detectedEmotion = targetEmotion;
        // Se mudou de emoção e passou um tempinho (2.5s), exibe o feedback empático
        if (now.difference(_lastMirrorReaction).inMilliseconds > 2500 && feedbackText.isNotEmpty) {
          _lastMirrorReaction = now;
          _lastMirroredEmotion = targetEmotion;
          _chatStatus = feedbackText;
          _isChatting = true;

          Timer(const Duration(seconds: 3), () {
            if (mounted && !_isSpeaking) {
              setState(() {
                _isChatting = false;
                _chatStatus = "";
              });
            }
          });
        }
      });
    } else if (targetEmotion == EyeEmotion.neutral && _detectedEmotion != EyeEmotion.neutral && !_isSpeaking) {
      // Retorna gradualmente ao neutro quando o usuário relaxa o rosto
      setState(() {
        _detectedEmotion = EyeEmotion.neutral;
      });
    }
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
    Offset lookAt = _cursorLookAt;
    if (_landmarks.isNotEmpty) {
      final nose = _landmarks[0];
      if (nose['visibility'] > 0.5) {
        // Na home usamos sempre a frontal, então invertemos o X
        double x = 1.0 - (nose['x'] as num).toDouble();
        double y = (nose['y'] as num).toDouble();
        lookAt = Offset(x, y);
      }
    }
    return Tooltip(
      message: "Cuidado! Não cutuque os olhos do robô!",
      child: CyberEyes(
        lookAt: lookAt,
        detectedEmotion: _detectedEmotion,
        isSpeaking: _isSpeaking,
        onEyePoked: (bool isLeft) {
          // Toca imediatamente o áudio local de dor do robô!
          _playSound("assets/aiai.mpeg".toJS);

          final String side = isLeft ? "esquerdo" : "direito";
          final List<String> painLines = [
            "Ai meu olho $side! Cuidado com esse dedo!",
            "Ai! Meus sensores visuais! Não enfia o dedo no meu olho!",
            "Epa! Ai meu olho! Isso doeu nos meus circuitos ópticos!",
          ];
          final String chosenLine = painLines[math.Random().nextInt(painLines.length)];

          setState(() {
            _chatStatus = "⚠️ $chosenLine";
            _isChatting = true;
            _isSpeaking = true;
          });

          final int speechDuration = 3000;

          _chatTimer?.cancel();
          _chatTimer = Timer(Duration(milliseconds: speechDuration), () {
            if (mounted) {
              setState(() {
                _isSpeaking = false;
              });
            }
          });

          Timer(Duration(milliseconds: speechDuration + 2500), () {
            if (mounted && !_isSpeaking) {
              setState(() {
                _isChatting = false;
                _chatStatus = "";
              });
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      drawer: isWide ? null : Drawer(
        width: 320,
        backgroundColor: const Color(0xFF0F172A),
        child: _buildSidebar(context, isDrawer: true),
      ),
      body: MouseRegion(
        onHover: (event) {
          final size = MediaQuery.of(context).size;
          if (size.width > 0 && size.height > 0) {
            final nx = (event.position.dx / size.width).clamp(0.0, 1.0);
            final ny = (event.position.dy / size.height).clamp(0.0, 1.0);
            setState(() {
              _cursorLookAt = Offset(nx, ny);
            });
          }
        },
        child: Stack(
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
          Row(
            children: [
              if (isWide) _buildSidebar(context),
              Expanded(
                child: Stack(
                  children: [
                    if (!isWide)
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white, size: 35),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                      ),
                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.contain,
                              child: _buildInteractiveEyes(),
                            ),
                            const SizedBox(height: 30),

                            // Interface de Conversa por Voz
                            AnimatedOpacity(
                              opacity: _isChatting ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 500),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: const Color(0xFF27AE60), width: 1),
                                  boxShadow: [BoxShadow(color: const Color(0xFF27AE60).withOpacity(0.2), blurRadius: 20)],
                                ),
                                child: Column(
                                  children: [
                                    Text("TERLINET COMUNICAÇÃO",
                                      style: GoogleFonts.orbitron(color: const Color(0xFF27AE60), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                    const Divider(color: Colors.white10, height: 20),
                                    Text(_chatStatus,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.vt323(color: Colors.white, fontSize: 18, letterSpacing: 1)),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Botão de Voz Principal (Estilo Cyberpunk)
                            GestureDetector(
                              onTap: _startVoiceInteraction,
                              child: _buildCyberMic(),
                            ),
                            const SizedBox(height: 15),
                            Text("TOQUE PARA CONVERSAR",
                              style: GoogleFonts.orbitron(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, {bool isDrawer = false}) {
    return Container(
      width: isDrawer ? null : 320,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(isDrawer ? 1.0 : 0.9),
        border: isDrawer ? null : const Border(right: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Column(
              children: [
                Text("TERLINET EYES",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.orbitron(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: Colors.white)),
                const Text("SISTEMA DE MONITORAMENTO IA",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF27AE60), letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),

                // Módulos de ativação rápida
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        _buildInteractiveCube(),
                        const Text("HELPER", style: TextStyle(fontSize: 8, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        _buildInteractiveTieFighter(),
                        const Text("DEFENSE", style: TextStyle(fontSize: 8, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                const Divider(color: Colors.white10),
                const SizedBox(height: 20),

                // Lista de Funcionalidades
                _buildFeatureCard(
                  icon: Icons.psychology,
                  title: "IA AVANÇADA",
                  description: "Análise de pose em tempo real local.",
                ),
                const SizedBox(height: 15),
                _buildFeatureCard(
                  icon: Icons.health_and_safety,
                  title: "HELPER ASSIST",
                  color: Colors.cyanAccent,
                  description: "Monitoramento e cuidado inteligente.",
                ),
                const SizedBox(height: 15),
                _buildFeatureCard(
                  icon: Icons.crop_free,
                  title: "ZONAS DINÂMICAS",
                  description: "Definição de perímetros seguros.",
                ),
                const SizedBox(height: 15),
                _buildFeatureCard(
                  icon: Icons.campaign,
                  title: "ALERTAS VOCAIS",
                  description: "Dissuasão imediata via IA.",
                ),
                const SizedBox(height: 15),
                _buildFeatureCard(
                  icon: Icons.photo_camera,
                  title: "EVIDÊNCIA DIGITAL",
                  description: "Captura de intrusão em tempo real.",
                ),
                const SizedBox(height: 15),
                _buildFeatureCard(
                  icon: Icons.shield,
                  title: "DEFENSE",
                  color: Colors.redAccent,
                  description: "Protocolo de neutralização laser.",
                ),
                const SizedBox(height: 15),
                _buildFeatureCard(
                  icon: Icons.add_chart,
                  title: "COUNTER",
                  color: Colors.orangeAccent,
                  description: "Estatísticas avançadas externas.",
                  onTap: () => _openUrl("https://terlinet.github.io/counter/".toJS, "_self".toJS),
                ),

                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                    minimumSize: const Size(double.infinity, 60),
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
                  child: const Text("INICIAR MONITORAMENTO",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13, letterSpacing: 2)),
                ),

                const SizedBox(height: 40),
                _buildPrivacyNotice(),
                const SizedBox(height: 20),
                const Text("V1.0 GOVERNANCE SYSTEM",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
              ],
            ),
          ),
        ),
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

  Widget _buildCyberMic() {
    final color = _isChatting ? Colors.redAccent : const Color(0xFF27AE60);
    return AnimatedBuilder(
      animation: _micController,
      builder: (context, child) {
        return Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black87,
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 15 + (10 * math.sin(_micController.value * 2 * math.pi)).abs(),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            _isChatting ? Icons.mic : Icons.mic_none,
            color: color,
            size: 35,
          ),
        );
      },
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
    await _tts.setSpeechRate(1.0); // Velocidade natural
    await _tts.setPitch(1.0); // Tom equilibrado e feminino

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

enum EyeEmotion { neutral, happy, angry, surprised, suspicious, love, sad, excited, thinking, silly, pain, sleepy }

class CyberEyes extends StatefulWidget {
  final Offset lookAt;
  final EyeEmotion? detectedEmotion;
  final bool isSpeaking;
  final VoidCallback? onPet;
  final Function(bool isLeft)? onEyePoked;
  const CyberEyes({super.key, required this.lookAt, this.detectedEmotion, this.isSpeaking = false, this.onPet, this.onEyePoked});

  @override
  State<CyberEyes> createState() => _CyberEyesState();
}

class _CyberEyesState extends State<CyberEyes> with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _pupilController;
  late AnimationController _emotionController;
  late AnimationController _breathingController;
  late AnimationController _talkingController;
  late AnimationController _painShakeController;
  late AnimationController _winkController;
  late AnimationController _particleController;

  EyeEmotion _currentEmotion = EyeEmotion.neutral;
  final math.Random _random = math.Random();
  Timer? _randomEmotionTimer;
  Timer? _idleTimer;
  bool _isPetting = false;
  bool _pokedLeft = false;
  bool _pokedRight = false;
  bool _isWinkingLeft = false;

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_currentEmotion == EyeEmotion.sleepy) {
      setState(() => _currentEmotion = EyeEmotion.surprised);
      _emotionController.forward(from: 0).then((_) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && _currentEmotion == EyeEmotion.surprised) {
            setState(() => _currentEmotion = EyeEmotion.neutral);
          }
        });
      });
    }
    // Entra em modo sono após 40s de inatividade
    _idleTimer = Timer(const Duration(seconds: 40), () {
      if (mounted && !widget.isSpeaking) {
        setState(() => _currentEmotion = EyeEmotion.sleepy);
        _emotionController.forward(from: 0);
      }
    });
  }

  void triggerWink() {
    _isWinkingLeft = _random.nextBool();
    _winkController.forward().then((_) {
      if (mounted) _winkController.reverse();
    });
  }

  void triggerPain(bool isLeft) {
    _resetIdleTimer();
    _randomEmotionTimer?.cancel();
    setState(() {
      _currentEmotion = EyeEmotion.pain;
      _pokedLeft = isLeft;
      _pokedRight = !isLeft;
    });

    _painShakeController.forward(from: 0);
    _emotionController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) {
        _emotionController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _pokedLeft = false;
              _pokedRight = false;
              _currentEmotion = EyeEmotion.suspicious;
            });
            _scheduleNextEmotion();
          }
        });
      }
    });
  }

  void pet() {
    _resetIdleTimer();
    _randomEmotionTimer?.cancel();
    setState(() {
      _isPetting = true;
      _currentEmotion = EyeEmotion.love;
    });
    _blinkController.forward().then((_) {
      if (mounted) _blinkController.reverse();
    });
    _emotionController.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          _emotionController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _isPetting = false;
                _currentEmotion = EyeEmotion.happy;
              });
              _scheduleNextEmotion();
            }
          });
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _pupilController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _emotionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _breathingController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _talkingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _painShakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _winkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

    _scheduleNextBlink();
    _scheduleNextEmotion();
    _resetIdleTimer();
  }

  @override
  void didUpdateWidget(CyberEyes oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resetIdleTimer();
    if (widget.detectedEmotion != null && widget.detectedEmotion != oldWidget.detectedEmotion) {
      _applyDetectedEmotion(widget.detectedEmotion!);
    }

    if (widget.isSpeaking != oldWidget.isSpeaking) {
      if (widget.isSpeaking) {
        _talkingController.repeat(reverse: true);
      } else {
        _talkingController.stop();
        _talkingController.reverse();
      }
    }
  }

  void _applyDetectedEmotion(EyeEmotion emotion) {
    _resetIdleTimer();
    _randomEmotionTimer?.cancel();
    setState(() => _currentEmotion = emotion);
    if (!_emotionController.isAnimating) {
      _emotionController.forward(from: 0);
    }
    // Quando o usuário relaxa o rosto (volta a neutral), transiciona rápido
    if (emotion == EyeEmotion.neutral) {
      _emotionController.reverse().then((_) {
        if (mounted && !widget.isSpeaking && _currentEmotion == EyeEmotion.neutral) {
          _scheduleNextEmotion();
        }
      });
      return;
    }
    // Se o usuário mantém uma expressão ou está falando, mantém vivo
    if (!widget.isSpeaking) {
      _randomEmotionTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !widget.isSpeaking) {
          _emotionController.reverse().then((_) {
            if (mounted && !widget.isSpeaking) {
              setState(() => _currentEmotion = EyeEmotion.neutral);
              _scheduleNextEmotion();
            }
          });
        }
      });
    }
  }

  void _scheduleNextBlink() {
    Future.delayed(Duration(seconds: 3 + _random.nextInt(5)), () {
      if (mounted) {
        // 25% de chance de dar uma piscadela charmosa (Wink) em vez de piscar os dois
        if (_random.nextDouble() < 0.25 && _currentEmotion == EyeEmotion.happy || _currentEmotion == EyeEmotion.neutral) {
          triggerWink();
        } else {
          _blinkController.forward().then((_) {
            if (mounted) _blinkController.reverse();
          });
        }
        _scheduleNextBlink();
      }
    });
  }

  void _scheduleNextEmotion() {
    Future.delayed(Duration(seconds: 4 + _random.nextInt(8)), () {
      if (mounted && _currentEmotion != EyeEmotion.sleepy) {
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
    _idleTimer?.cancel();
    _blinkController.dispose();
    _pupilController.dispose();
    _emotionController.dispose();
    _breathingController.dispose();
    _talkingController.dispose();
    _painShakeController.dispose();
    _winkController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breathingController, _talkingController, _painShakeController]),
      builder: (context, child) {
        // Tremor cômico quando sente dor
        double shakeX = 0;
        double shakeY = 0;
        if (_painShakeController.isAnimating) {
          double shakeIntensity = (1.0 - _painShakeController.value) * 12;
          shakeX = math.sin(_painShakeController.value * 20 * math.pi) * shakeIntensity;
          shakeY = math.cos(_painShakeController.value * 20 * math.pi) * (shakeIntensity * 0.5);
        }

        return Transform.translate(
          offset: Offset(shakeX, (5 * math.sin(_breathingController.value * 2 * math.pi)) + shakeY),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Linha dos Olhos com Efeitos Holográficos Flutuantes
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Olho Esquerdo com detecção direta de toque (dor no olho)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        triggerPain(true);
                        widget.onEyePoked?.call(true);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(size: const Size(200, 200), painter: EyeHUDPainter()),
                          AnimatedBuilder(
                            animation: _winkController,
                            builder: (context, child) {
                              final EyeEmotion leftEmotion = (_currentEmotion == EyeEmotion.pain)
                                  ? (_pokedLeft ? EyeEmotion.pain : EyeEmotion.surprised)
                                  : _currentEmotion;
                              final Offset leftLook = (_currentEmotion == EyeEmotion.pain && !_pokedLeft)
                                  ? const Offset(0.85, 0.5) // olha chocado para o olho direito machucado
                                  : widget.lookAt;

                              return CyberEye(
                                isLeft: true,
                                lookAt: leftLook,
                                blinkController: _blinkController,
                                pupilController: _pupilController,
                                emotionController: _emotionController,
                                currentEmotion: leftEmotion,
                                winkFactor: _isWinkingLeft ? _winkController.value : 0.0,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  // Olho Direito com detecção direta de toque (dor no olho)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        triggerPain(false);
                        widget.onEyePoked?.call(false);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(size: const Size(200, 200), painter: EyeHUDPainter()),
                          AnimatedBuilder(
                            animation: _winkController,
                            builder: (context, child) {
                              final EyeEmotion rightEmotion = (_currentEmotion == EyeEmotion.pain)
                                  ? (_pokedRight ? EyeEmotion.pain : EyeEmotion.surprised)
                                  : _currentEmotion;
                              final Offset rightLook = (_currentEmotion == EyeEmotion.pain && !_pokedRight)
                                  ? const Offset(0.15, 0.5) // olha chocado para o olho esquerdo machucado
                                  : widget.lookAt;

                              return CyberEye(
                                isLeft: false,
                                lookAt: rightLook,
                                blinkController: _blinkController,
                                pupilController: _pupilController,
                                emotionController: _emotionController,
                                currentEmotion: rightEmotion,
                                winkFactor: !_isWinkingLeft ? _winkController.value : 0.0,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Partículas Emocionais Flutuantes (Corações, Lágrimas, Zzz de sono)
              AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  final pVal = _particleController.value;
                  if (_currentEmotion == EyeEmotion.love) {
                    return Positioned(
                      top: -10 - (20 * pVal),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: (1.0 - pVal).clamp(0.0, 1.0),
                            child: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 28),
                          ),
                          const SizedBox(width: 80),
                          Opacity(
                            opacity: (1.0 - pVal).clamp(0.0, 1.0),
                            child: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 22),
                          ),
                        ],
                      ),
                    );
                  } else if (_currentEmotion == EyeEmotion.sleepy) {
                    return Positioned(
                      top: -15 - (25 * pVal),
                      right: 40,
                      child: Opacity(
                        opacity: (1.0 - pVal).clamp(0.0, 1.0),
                        child: Text("Zzz...",
                          style: GoogleFonts.vt323(color: Colors.cyanAccent, fontSize: 26, fontWeight: FontWeight.bold)),
                      ),
                    );
                  } else if (_currentEmotion == EyeEmotion.pain || _currentEmotion == EyeEmotion.sad) {
                    final bool showLeftTear = _currentEmotion == EyeEmotion.sad || (_currentEmotion == EyeEmotion.pain && _pokedLeft);
                    final bool showRightTear = _currentEmotion == EyeEmotion.sad || (_currentEmotion == EyeEmotion.pain && _pokedRight);
                    return Positioned(
                      bottom: 10 + (25 * pVal),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: showLeftTear ? (1.0 - pVal).clamp(0.0, 1.0) : 0.0,
                            child: const Icon(Icons.water_drop, color: Colors.cyanAccent, size: 20),
                          ),
                          const SizedBox(width: 140),
                          Opacity(
                            opacity: showRightTear ? (1.0 - pVal).clamp(0.0, 1.0) : 0.0,
                            child: const Icon(Icons.water_drop, color: Colors.cyanAccent, size: 20),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          // Efeito de Blush de Anime
          AnimatedBuilder(
            animation: _emotionController,
            builder: (context, child) {
              bool showBlush = _currentEmotion == EyeEmotion.love || _currentEmotion == EyeEmotion.excited;
              return Opacity(
                opacity: showBlush ? _emotionController.value : 0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(2, (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 50),
                      width: 40, height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(colors: [Colors.pinkAccent.withOpacity(0.3), Colors.transparent])
                      ),
                    )),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          CyberMouth(
            emotion: _currentEmotion,
            emotionController: _emotionController,
            isTalking: widget.isSpeaking,
            talkingProgress: _talkingController.value,
            pokedLeft: _pokedLeft,
            pokedRight: _pokedRight,
            painShakeController: _painShakeController,
            talkingController: _talkingController,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class CyberMouth extends StatelessWidget {
  final EyeEmotion emotion;
  final AnimationController emotionController;
  final bool isTalking;
  final double talkingProgress;
  final bool pokedLeft;
  final bool pokedRight;
  final AnimationController? painShakeController;
  final AnimationController? talkingController;

  const CyberMouth({
    super.key,
    required this.emotion,
    required this.emotionController,
    this.isTalking = false,
    this.talkingProgress = 0,
    this.pokedLeft = false,
    this.pokedRight = false,
    this.painShakeController,
    this.talkingController,
  });

  @override
  Widget build(BuildContext context) {
    final List<Listenable> anims = [emotionController];
    if (painShakeController != null) anims.add(painShakeController!);
    if (talkingController != null) anims.add(talkingController!);

    return AnimatedBuilder(
      animation: Listenable.merge(anims),
      builder: (context, child) {
        return CustomPaint(
          size: const Size(120, 48),
          painter: MouthPainter(
            emotion: emotion,
            progress: emotionController.value,
            isTalking: isTalking,
            talkingProgress: talkingController?.value ?? talkingProgress,
            pokedLeft: pokedLeft,
            pokedRight: pokedRight,
            painShake: painShakeController?.value ?? 0.0,
          ),
        );
      },
    );
  }
}

class MouthPainter extends CustomPainter {
  final EyeEmotion emotion;
  final double progress;
  final bool isTalking;
  final double talkingProgress;
  final bool pokedLeft;
  final bool pokedRight;
  final double painShake;

  MouthPainter({
    required this.emotion,
    required this.progress,
    required this.isTalking,
    required this.talkingProgress,
    this.pokedLeft = false,
    this.pokedRight = false,
    this.painShake = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Define a cor temática da boca baseada na emoção
    Color themeColor = const Color(0xFF27AE60);
    if (emotion == EyeEmotion.love) themeColor = Colors.pinkAccent;
    if (emotion == EyeEmotion.angry) themeColor = Colors.redAccent;
    if (emotion == EyeEmotion.sad) themeColor = Colors.cyan;
    if (emotion == EyeEmotion.pain) themeColor = Colors.orangeAccent;

    final cavityPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.red[900]!, Colors.black],
        center: Alignment.center,
        radius: 1.0,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final teethPaint = Paint()..color = Colors.white;
    final tonguePaint = Paint()..color = Colors.pinkAccent[100]!;
    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Se for DOR: Prioridade máxima! Desenha expressão rica de dor (falando ou calado)
    if (emotion == EyeEmotion.pain) {
      _drawPainMouth(canvas, size, centerX, centerY, cavityPaint, teethPaint, strokePaint);
      return;
    }

    final path = Path();

    // Lógica de FALA para demais emoções
    if (isTalking) {
      double mouthOpen = 10 + (15 * talkingProgress);
      path.moveTo(centerX - 35, centerY - 5);
      path.quadraticBezierTo(centerX, centerY + mouthOpen, centerX + 35, centerY - 5);
      path.quadraticBezierTo(centerX, centerY - 5, centerX - 35, centerY - 5);

      canvas.drawPath(path, cavityPaint);

      // Dentes (Sempre visíveis ao falar)
      final teethPath = Path();
      teethPath.moveTo(centerX - 30, centerY - 4);
      teethPath.quadraticBezierTo(centerX, centerY + 2, centerX + 30, centerY - 4);
      teethPath.lineTo(centerX + 30, centerY - 8);
      teethPath.lineTo(centerX - 30, centerY - 8);
      teethPath.close();
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(teethPath, teethPaint);
      canvas.restore();
      return;
    }

    switch (emotion) {
      case EyeEmotion.happy:
      case EyeEmotion.love:
      case EyeEmotion.excited:
        double openAmount = (emotion == EyeEmotion.excited ? 25 : 15) * progress;
        path.moveTo(centerX - 35, centerY - 5);
        path.quadraticBezierTo(centerX, centerY + openAmount, centerX + 35, centerY - 5);
        path.quadraticBezierTo(centerX, centerY - 10 * progress, centerX - 35, centerY - 5);

        canvas.drawPath(path, cavityPaint);

        // Dentes superiores
        final teethPath = Path();
        teethPath.moveTo(centerX - 30, centerY - 4);
        teethPath.quadraticBezierTo(centerX, centerY + 2, centerX + 30, centerY - 4);
        teethPath.lineTo(centerX + 30, centerY - 8);
        teethPath.lineTo(centerX - 30, centerY - 8);
        teethPath.close();
        canvas.save();
        canvas.clipPath(path);
        canvas.drawPath(teethPath, teethPaint);

        // Língua (no Excited)
        if (emotion == EyeEmotion.excited) {
          final tonguePath = Path();
          tonguePath.addOval(Rect.fromCenter(center: Offset(centerX, centerY + 15), width: 30, height: 20));
          canvas.drawPath(tonguePath, tonguePaint);
        }
        canvas.restore();
        break;

      case EyeEmotion.silly:
        // Apenas a língua aparece
        final tonguePath = Path();
        tonguePath.moveTo(centerX - 10, centerY + 5);
        tonguePath.quadraticBezierTo(centerX, centerY + 30 * progress, centerX + 10, centerY + 5);
        tonguePath.close();

        canvas.drawPath(tonguePath, tonguePaint);
        break;

      case EyeEmotion.surprised:
        path.addOval(Rect.fromCenter(center: Offset(centerX, centerY), width: 30 * progress, height: 35 * progress));
        canvas.drawPath(path, cavityPaint);
        break;

      case EyeEmotion.angry:
      case EyeEmotion.sad:
        path.moveTo(centerX - 30, centerY + 10 * progress);
        path.quadraticBezierTo(centerX, centerY - 5 * progress, centerX + 30, centerY + 10 * progress);
        if (emotion == EyeEmotion.angry) {
          path.quadraticBezierTo(centerX, centerY + 15 * progress, centerX - 30, centerY + 10 * progress);
          canvas.drawPath(path, cavityPaint);
          final gritPath = Path();
          gritPath.addRect(Rect.fromCenter(center: Offset(centerX, centerY + 2), width: 40, height: 4));
          canvas.save();
          canvas.clipPath(path);
          canvas.drawPath(gritPath, teethPaint);
          canvas.restore();
        } else {
          canvas.drawPath(path, strokePaint);
        }
        break;

      case EyeEmotion.sleepy:
        // Bocejo fofo quando com sono
        path.addOval(Rect.fromCenter(center: Offset(centerX, centerY + 3), width: 22 * progress, height: 18 * progress));
        canvas.drawPath(path, cavityPaint);
        break;

      default:
        path.moveTo(centerX - 20, centerY);
        path.lineTo(centerX + 20, centerY);
        canvas.drawPath(path, strokePaint);
        break;
    }
  }

  void _drawPainMouth(
    Canvas canvas,
    Size size,
    double centerX,
    double centerY,
    Paint cavityPaint,
    Paint teethPaint,
    Paint strokePaint,
  ) {
    // Tremor cômico de dor com atenuação
    final double shake = painShake > 0
        ? math.sin(painShake * 24 * math.pi) * (1.0 - painShake) * 3.5
        : 0.0;

    // Assimetria: o canto do lado cutucado repuxa para cima em esgar de dor
    double leftCornerY = centerY + 3 + shake;
    double rightCornerY = centerY + 3 - shake;

    if (pokedLeft) {
      leftCornerY = centerY - 8 + shake; // repuxa para cima no olho esquerdo machucado
      rightCornerY = centerY + 7 - shake;
    } else if (pokedRight) {
      rightCornerY = centerY - 8 + shake; // repuxa para cima no olho direito machucado
      leftCornerY = centerY + 7 - shake;
    }

    final double leftX = centerX - 38;
    final double rightX = centerX + 38;

    final teethLinePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final outlinePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final stressPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    if (isTalking) {
      // BOCA ABERTA EM GRITO / GEMIDO DE DOR
      final double mouthOpen = 14 + (18 * talkingProgress);
      final painPath = Path();
      painPath.moveTo(leftX, leftCornerY);
      // Lábio superior arqueado em esgar de dor
      painPath.quadraticBezierTo(centerX, centerY - 10 + (shake * 0.5), rightX, rightCornerY);
      // Lábio inferior escancarado em agonia
      painPath.quadraticBezierTo(centerX, centerY + mouthOpen, leftX, leftCornerY);
      painPath.close();

      // Cavidade escura avermelhada
      canvas.drawPath(painPath, cavityPaint);

      // Salva para recortar os dentes dentro da boca
      canvas.save();
      canvas.clipPath(painPath);

      // Fileira superior de dentes expostos
      final topTeeth = Path();
      topTeeth.moveTo(leftX + 4, leftCornerY);
      topTeeth.quadraticBezierTo(centerX, centerY - 10, rightX - 4, rightCornerY);
      topTeeth.lineTo(rightX - 4, centerY - 1);
      topTeeth.quadraticBezierTo(centerX, centerY - 1, leftX + 4, centerY - 1);
      topTeeth.close();
      canvas.drawPath(topTeeth, teethPaint);

      // Divisórias dos dentes superiores
      for (int i = 1; i <= 6; i++) {
        final double t = i / 7.0;
        final double tx = leftX + 6 + (rightX - leftX - 12) * t;
        canvas.drawLine(Offset(tx, centerY - 9), Offset(tx, centerY - 1), teethLinePaint);
      }

      // Fileira inferior de dentes
      final bottomTeeth = Path();
      final double botY = centerY + mouthOpen;
      bottomTeeth.moveTo(leftX + 6, botY - 9);
      bottomTeeth.quadraticBezierTo(centerX, botY - 8, rightX - 6, botY - 9);
      bottomTeeth.lineTo(rightX - 6, botY);
      bottomTeeth.quadraticBezierTo(centerX, botY, leftX + 6, botY);
      bottomTeeth.close();
      canvas.drawPath(bottomTeeth, teethPaint);

      // Divisórias dos dentes inferiores
      for (int i = 1; i <= 5; i++) {
        final double t = i / 6.0;
        final double tx = leftX + 8 + (rightX - leftX - 16) * t;
        canvas.drawLine(Offset(tx, botY - 9), Offset(tx, botY), teethLinePaint);
      }

      canvas.restore();

      // Contorno da boca
      canvas.drawPath(painPath, outlinePaint);
    } else {
      // BOCA CERRANDO OS DENTES COM TREMOR (ESGAR DE DOR / CRINGE)
      final grimacePath = Path();
      final double mouthHeight = 11 + (4 * progress);

      grimacePath.moveTo(leftX, leftCornerY);
      grimacePath.quadraticBezierTo(centerX, centerY - 5 + shake, rightX, rightCornerY);
      grimacePath.quadraticBezierTo(centerX, centerY - 5 + mouthHeight + shake, leftX, leftCornerY + mouthHeight);
      grimacePath.close();

      // Fundo escuro
      canvas.drawPath(grimacePath, cavityPaint);

      canvas.save();
      canvas.clipPath(grimacePath);

      // Preenchimento dos dentes cerrados
      final teethBand = Path();
      teethBand.addRect(Rect.fromLTWH(leftX - 5, centerY - 15, (rightX - leftX) + 10, 35));
      canvas.drawPath(teethBand, teethPaint);

      // Linha horizontal central de mordida
      final biteLine = Path();
      biteLine.moveTo(leftX, leftCornerY + (mouthHeight * 0.5));
      biteLine.quadraticBezierTo(
        centerX,
        centerY - 5 + (mouthHeight * 0.5) + shake,
        rightX,
        rightCornerY + (mouthHeight * 0.5),
      );
      canvas.drawPath(biteLine, teethLinePaint..strokeWidth = 2.0);

      // Linhas verticais separando dentes (estilo anime grimace clássico)
      for (int i = 1; i <= 7; i++) {
        final double t = i / 8.0;
        final double tx = leftX + 5 + (rightX - leftX - 10) * t;
        final double topY = centerY - 5 + shake + (leftCornerY - (centerY - 5)) * (1.0 - t);
        final double bY = topY + mouthHeight;
        canvas.drawLine(Offset(tx, topY), Offset(tx, bY), teethLinePaint..strokeWidth = 1.3);
      }

      canvas.restore();

      // Contorno externo nítido
      canvas.drawPath(grimacePath, outlinePaint);
    }

    // Traços de tensão/dor nos cantos da boca (estilo anime)
    if (pokedLeft) {
      canvas.drawLine(Offset(leftX - 3, leftCornerY - 3), Offset(leftX - 9, leftCornerY - 9), stressPaint);
      canvas.drawLine(Offset(leftX - 1, leftCornerY + 4), Offset(leftX - 7, leftCornerY + 8), stressPaint);
    } else if (pokedRight) {
      canvas.drawLine(Offset(rightX + 3, rightCornerY - 3), Offset(rightX + 9, rightCornerY - 9), stressPaint);
      canvas.drawLine(Offset(rightX + 1, rightCornerY + 4), Offset(rightX + 7, rightCornerY + 8), stressPaint);
    } else {
      canvas.drawLine(Offset(leftX - 3, leftCornerY - 2), Offset(leftX - 7, leftCornerY + 4), stressPaint);
      canvas.drawLine(Offset(rightX + 3, rightCornerY - 2), Offset(rightX + 7, rightCornerY + 4), stressPaint);
    }
  }

  @override
  bool shouldRepaint(MouthPainter oldDelegate) =>
      oldDelegate.emotion != emotion ||
      oldDelegate.progress != progress ||
      oldDelegate.isTalking != isTalking ||
      oldDelegate.talkingProgress != talkingProgress ||
      oldDelegate.pokedLeft != pokedLeft ||
      oldDelegate.pokedRight != pokedRight ||
      oldDelegate.painShake != painShake;
}

class CyberEye extends StatelessWidget {
  final bool isLeft;
  final Offset lookAt;
  final AnimationController blinkController;
  final AnimationController pupilController;
  final AnimationController emotionController;
  final EyeEmotion currentEmotion;
  final double winkFactor;

  const CyberEye({
    super.key,
    required this.isLeft,
    required this.lookAt,
    required this.blinkController,
    required this.pupilController,
    required this.emotionController,
    required this.currentEmotion,
    this.winkFactor = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    double lookX = (lookAt.dx - 0.5).clamp(-0.4, 0.4) * 60;
    double lookY = (lookAt.dy - 0.5).clamp(-0.4, 0.4) * 60;

    // Lógica especial para emoção "Thinking" (olha para cima)
    if (currentEmotion == EyeEmotion.thinking) {
      lookY = -40 * emotionController.value;
      lookX = (isLeft ? 20 : 10) * emotionController.value;
    }

    return Container(
      width: 160, height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10, width: 2),
        boxShadow: [BoxShadow(color: const Color(0xFF27AE60).withOpacity(0.1), blurRadius: 40, spreadRadius: 5)],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(color: const Color(0xFF0F172A)),
            // Íris e Pupila
            Transform(
              transform: Matrix4.identity()..setEntry(3, 2, 0.002)..rotateY(lookX * 0.005)..rotateX(-lookY * 0.005)..translate(lookX, lookY),
              child: AnimatedBuilder(
                animation: Listenable.merge([pupilController, emotionController]),
                builder: (context, child) {
                  Color irisColor = const Color(0xFF27AE60);
                  if (currentEmotion == EyeEmotion.love) irisColor = Colors.pinkAccent;
                  if (currentEmotion == EyeEmotion.angry) irisColor = Colors.redAccent;
                  if (currentEmotion == EyeEmotion.sad) irisColor = Colors.cyan;
                  if (currentEmotion == EyeEmotion.pain) irisColor = Colors.orangeAccent;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Íris
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [irisColor.withOpacity(0.8), irisColor, Colors.black],
                            stops: const [0.2, 0.7, 1.0]
                          ),
                        ),
                      ),
                      // Pupila
                      Container(
                        width: (currentEmotion == EyeEmotion.surprised || currentEmotion == EyeEmotion.sad || currentEmotion == EyeEmotion.pain)
                          ? 16 // Pupila bem contraída para dor/choque
                          : 45 + (10 * pupilController.value),
                        height: (currentEmotion == EyeEmotion.surprised || currentEmotion == EyeEmotion.sad || currentEmotion == EyeEmotion.pain)
                          ? 16
                          : 45 + (10 * pupilController.value),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                        child: currentEmotion == EyeEmotion.love
                          ? const Center(child: Icon(Icons.favorite, color: Colors.pinkAccent, size: 25))
                          : currentEmotion == EyeEmotion.excited
                            ? const Center(child: Icon(Icons.star, color: Colors.yellowAccent, size: 30))
                            : currentEmotion == EyeEmotion.pain
                              ? const Center(child: Icon(Icons.close, color: Colors.redAccent, size: 14))
                              : null,
                      ),
                      // Brilhos de Anime (Catchlights) com Parallax Dinâmico
                      Positioned(
                        top: 20 - (lookY * 0.15),
                        left: 30 + (lookX * 0.15),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.45),
                            boxShadow: [
                              BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 30 + (lookY * 0.1),
                        right: 40 - (lookX * 0.1),
                        child: Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.35),
                          ),
                        ),
                      ),
                      if (currentEmotion == EyeEmotion.excited)
                        ...List.generate(3, (i) => Positioned(
                          top: 40.0 + (i * 20), left: 20,
                          child: Icon(Icons.wb_sunny_outlined, color: Colors.white.withOpacity(0.5), size: 15),
                        )),
                    ],
                  );
                },
              ),
            ),
            // Pálpebras Estilizadas
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
                    bottomEyelidHeight = 60 * val;
                    break;
                  case EyeEmotion.angry:
                    topEyelidHeight = 50 * val;
                    topRotation = (isLeft ? 0.3 : -0.3) * val;
                    bottomEyelidHeight = 15 * val;
                    break;
                  case EyeEmotion.surprised:
                    eyeScale = 1.0 + (0.2 * val);
                    break;
                  case EyeEmotion.suspicious:
                    topEyelidHeight = 45 * val;
                    bottomEyelidHeight = 45 * val;
                    break;
                  case EyeEmotion.sad:
                    topEyelidHeight = 30 * val;
                    topRotation = (isLeft ? -0.15 : 0.15) * val;
                    bottomEyelidHeight = 10 * val;
                    break;
                  case EyeEmotion.pain:
                    // Olhos bem apertados de dor com tremor
                    topEyelidHeight = 65 * val;
                    bottomEyelidHeight = 65 * val;
                    topRotation = (isLeft ? 0.35 : -0.35) * val;
                    eyeScale = 0.92;
                    break;
                  case EyeEmotion.thinking:
                    // Assimetria charmosa: uma sobrancelha mais levantada e pálpebra curiosa
                    topEyelidHeight = (isLeft ? 15 : 45) * val;
                    topRotation = (isLeft ? -0.15 : 0.25) * val;
                    break;
                  case EyeEmotion.sleepy:
                    // Pálpebras caídas de sono
                    topEyelidHeight = 55 * val;
                    bottomEyelidHeight = 25 * val;
                    break;
                  default: break;
                }

                // Aplica piscadela única (Wink) ou piscar normal
                double effectiveBlink = math.max(blinkController.value, winkFactor);
                if (effectiveBlink > 0) {
                  topEyelidHeight = 80 * effectiveBlink;
                  bottomEyelidHeight = 80 * effectiveBlink;
                  topRotation = 0;
                }

                return Transform.scale(
                  scale: eyeScale,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Sobrancelha Estilizada
                      Positioned(
                        top: -25 - (15 * val),
                        left: isLeft ? 10 : -10,
                        right: isLeft ? -10 : 10,
                        child: Transform.rotate(
                          angle: topRotation * 1.5,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(color: (currentEmotion == EyeEmotion.angry ? Colors.red : const Color(0xFF27AE60)).withOpacity(0.6), blurRadius: 10, spreadRadius: 1)
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Pálpebra Superior
                      Align(
                        alignment: Alignment.topCenter,
                        child: Transform.rotate(
                          angle: topRotation,
                          child: Container(
                            height: (80 * blinkController.value + topEyelidHeight).clamp(0.0, 85.0),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E293B),
                              border: Border(bottom: BorderSide(color: Colors.black, width: 4))
                            ),
                          ),
                        ),
                      ),
                      // Pálpebra Inferior
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: (80 * blinkController.value + bottomEyelidHeight).clamp(0.0, 85.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(currentEmotion == EyeEmotion.happy ? 100 * val : 0)),
                            border: const Border(top: BorderSide(color: Colors.black, width: 2))
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
    // Linhas de HUD removidas
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