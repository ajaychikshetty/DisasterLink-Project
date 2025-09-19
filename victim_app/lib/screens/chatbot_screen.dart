import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:victim_app/bloc/chat_bloc.dart';
import 'package:victim_app/models/ChatBot.dart';

class ChatBot extends StatefulWidget {
  const ChatBot({super.key});

  @override
  State<ChatBot> createState() => _ChatBotState();
}

class _ChatBotState extends State<ChatBot> with TickerProviderStateMixin {
  final ChatBloc chatBloc = ChatBloc();
  TextEditingController textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Speech to Text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';
  double _confidence = 1.0;

  // Text to Speech
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  String? _currentSpeakingMessageId;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTts();
  }

  void _initializeSpeech() async {
    _speech = stt.SpeechToText();
    bool available = await _speech.initialize(
      onStatus: (val) => print('onStatus: $val'),
      onError: (val) => print('onError: $val'),
    );
    if (available) {
      setState(() {});
    } else {
      print("The user has denied the use of speech recognition.");
    }
  }

  void _initializeTts() async {
    _flutterTts = FlutterTts();

    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
        _currentSpeakingMessageId = null;
      });
    });

    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isSpeaking = false;
        _currentSpeakingMessageId = null;
      });
    });
  }

  void _listen() async {
    // Request microphone permission
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for speech recognition'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
            if (val.hasConfidenceRating && val.confidence > 0) {
              _confidence = val.confidence;
            }
          }),
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          localeId: "en_US",
          onSoundLevelChange: (level) => {},
          cancelOnError: true,
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      
      // If we have recognized text, add it to the chat
      if (_text.isNotEmpty) {
        textEditingController.text = _text;
        String text = _text.trim();
        textEditingController.clear();
        setState(() => _text = '');
        chatBloc.add(
          ChatGenerateNewTextMessageEvent(
            inputMessage: text,
          ),
        );
      }
    }
  }

  void _speak(String text, String messageId) async {
    if (_isSpeaking && _currentSpeakingMessageId == messageId) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
        _currentSpeakingMessageId = null;
      });
    } else {
      if (_isSpeaking) {
        await _flutterTts.stop();
      }
      setState(() {
        _currentSpeakingMessageId = messageId;
      });
      await _flutterTts.speak(text);
    }
  }

  // Robot animation states
  String get _currentRobotAnimation {
    if (chatBloc.generating) {
      return 'assets/robot/robot_thinking.gif';
    } else {
      // Check if bot just responded
      final state = chatBloc.state;
      if (state is ChatSuccessState && state.messages.isNotEmpty) {
        final lastMessage = state.messages.last;
        if (lastMessage.role != "user") {
          return 'assets/robot/robot_answering.gif';
        }
      }
    }
    return 'assets/robot/robot_idle.gif';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Row(
          children: [
            const SizedBox(width: 12),
            Text(
              "Disaster Assistant",
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
         Container(
          margin: EdgeInsets.only(right: 25),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.support_agent,
                color: Colors.green,
                size: 24,
              ),
            ),
        ],
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
        bloc: chatBloc,
        listener: (context, state) {
          if (state is ChatSuccessState) {
            _scrollToBottom();
          }
        },
        builder: (context, state) {
          switch (state.runtimeType) {
            case ChatSuccessState:
              List<ChatMessageModel> messages =
                  (state as ChatSuccessState).messages;
              return Container(
                color: Colors.black,
                child: Column(
                  children: [
                    // Top Section - Robot Mascot
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Hero(
                            tag: "robot_mascot",
                            child: SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: Image.asset(
                                _currentRobotAnimation,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            chatBloc.generating
                                ? "Thinking..."
                                : _isListening 
                                    ? "Listening..."
                                    : "How can I help you today?",
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_isListening && _text.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _text,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Middle Section - Chat Messages
                    Expanded(
                      child: Container(
                        color: Colors.black,
                        child: messages.isEmpty
                            ? Center(
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 64,
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        "Start a conversation!",
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Ask me about disaster management,\nemergency procedures, or safety tips.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white60,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final isUser = message.role == "user";
                                  final messageId = "${message.role}_$index";

                                  return Container(
                                    margin: EdgeInsets.only(
                                      top: 8,
                                      bottom: 8,
                                      left: isUser ? 60 : 16,
                                      right: isUser ? 16 : 60,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: isUser
                                          ? MainAxisAlignment.end
                                          : MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (!isUser) ...[
                                          Container(
                                            width: 36,
                                            height: 36,
                                            margin: const EdgeInsets.only(
                                              right: 12,
                                              top: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.green.withOpacity(
                                                0.1,
                                              ),
                                              border: Border.all(
                                                color: Colors.green.withOpacity(
                                                  0.3,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: ClipOval(
                                              child: Image.asset(
                                                'assets/robot/robot_idle.gif',
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ],
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: isUser
                                                  ? Colors.green
                                                  : Colors.grey[900],
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(
                                                  isUser ? 20 : 4,
                                                ),
                                                topRight: Radius.circular(
                                                  isUser ? 4 : 20,
                                                ),
                                                bottomLeft:
                                                    const Radius.circular(20),
                                                bottomRight:
                                                    const Radius.circular(20),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                              border: !isUser
                                                  ? Border.all(
                                                      color: Colors.green
                                                          .withOpacity(0.3),
                                                      width: 1,
                                                    )
                                                  : null,
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  message.parts.first.text,
                                                  style: TextStyle(
                                                    color: isUser
                                                        ? Colors.white
                                                        : Colors.white70,
                                                    fontSize: 16,
                                                    height: 1.4,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                                if (!isUser) ...[
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () => _speak(
                                                          message.parts.first.text,
                                                          messageId,
                                                        ),
                                                        child: Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: _currentSpeakingMessageId == messageId
                                                                ? Colors.green.withOpacity(0.2)
                                                                : Colors.green.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(20),
                                                            border: Border.all(
                                                              color: Colors.green.withOpacity(0.3),
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(
                                                                _currentSpeakingMessageId == messageId && _isSpeaking
                                                                    ? Icons.stop
                                                                    : Icons.volume_up,
                                                                color: Colors.green,
                                                                size: 16,
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                _currentSpeakingMessageId == messageId && _isSpeaking
                                                                    ? "Stop"
                                                                    : "Play",
                                                                style: const TextStyle(
                                                                  color: Colors.green,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),

                    // Loading indicator when bot is generating
                    if (chatBloc.generating)
                      Container(
                        color: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green.withOpacity(0.1),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/robot/robot_thinking.gif',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(20),
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 50,
                                    width: 100,
                                    child: Lottie.asset(
                                      'assets/loader.json',
                                      height: 50,
                                      width: 100,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Row(
                          children: [
                            // Microphone button
                            GestureDetector(
                              onTap: _listen,
                              child: Container(
                                height: 56,
                                width: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _isListening
                                        ? [
                                            Colors.red.shade600,
                                            Colors.red.shade700,
                                          ]
                                        : [
                                            Colors.blue.shade600,
                                            Colors.blue.shade700,
                                          ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isListening ? Colors.red : Colors.blue)
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isListening ? Icons.mic : Icons.mic_none,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: TextField(
                                  controller: textEditingController,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  maxLines: null,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (value) {
                                    if (value.trim().isNotEmpty) {
                                      String text = value.trim();
                                      textEditingController.clear();
                                      chatBloc.add(
                                        ChatGenerateNewTextMessageEvent(
                                          inputMessage: text,
                                        ),
                                      );
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: _isListening 
                                        ? "Listening..." 
                                        : "Type or speak...",
                                    hintStyle: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 16,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: chatBloc.generating || _isListening
                                  ? null
                                  : () {
                                      if (textEditingController.text
                                          .trim()
                                          .isNotEmpty) {
                                        String text = textEditingController.text
                                            .trim();
                                        textEditingController.clear();
                                        chatBloc.add(
                                          ChatGenerateNewTextMessageEvent(
                                            inputMessage: text,
                                          ),
                                        );
                                      }
                                    },
                              child: Container(
                                height: 56,
                                width: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: (chatBloc.generating || _isListening)
                                        ? [
                                            Colors.grey.shade700,
                                            Colors.grey.shade800,
                                          ]
                                        : [
                                            Colors.green.shade600,
                                            Colors.green.shade700,
                                          ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  (chatBloc.generating || _isListening)
                                      ? Icons.hourglass_empty
                                      : Icons.send_rounded,
                                  color: Colors.white,
                                  size: 24,
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

            default:
              return Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
              );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    textEditingController.dispose();
    _flutterTts.stop();
    super.dispose();
  }
}