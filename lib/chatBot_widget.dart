

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:Sketchbot/gpt.dart';
import 'package:Sketchbot/gemini.dart'; 
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter_tts/flutter_tts.dart'; 

class ChatMessage {
  String text;
  bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatBotWidget extends StatefulWidget {
  final TextEditingController mainTextController;
  final TextEditingController messageController;
  final FocusNode? focusNode;
  final Function(bool) onToggleHandwriting;
  final bool normalKeyBoard;
  final bool showHandwritingWidget;
  final Function? onTextUpdated;

  const ChatBotWidget({
    Key? key,
    required this.mainTextController,
    required this.messageController,
    this.focusNode,
    required this.onToggleHandwriting,
    required this.normalKeyBoard,
    required this.showHandwritingWidget,
    required this.onTextUpdated,
  }) : super(key: key);

  @override
  _ChatBotWidgetState createState() => _ChatBotWidgetState();
}

class _ChatBotWidgetState extends State<ChatBotWidget> {
  List<ChatMessage> messages = [];
  ScrollController scrollController = ScrollController();
  GPT gpt = GPT();
  GeminiChatBot gemini = GeminiChatBot();
  String selectedApi = "Gemini";

  final stt.SpeechToText _speech = stt.SpeechToText();
  FlutterTts flutterTts = FlutterTts();
  bool _isListening = false;
  bool _hasSpeech = false;
  bool _isSpeaking = false;
  String _speechText = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    if (widget.focusNode != null) {
      widget.focusNode!.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    if (widget.focusNode != null) {
      widget.focusNode!.removeListener(_handleFocusChange);
    }
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onError: (val) => print('onError: $val'),
      onStatus: (val) => print('onStatus: $val'),
    );
    if (available) {
      setState(() => _hasSpeech = true);
    }
  }

  Future<void> _initTts() async {
    flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  void _handleFocusChange() {
    if (widget.focusNode != null && widget.focusNode!.hasFocus) {
      print("Textfeld ist fokussiert");
    }
  }

  void _sendMessage() {
    final fullText = widget.mainTextController.text;
    final selection = widget.mainTextController.selection;
    String selectedText = selection.isValid && !selection.isCollapsed
        ? selection.textInside(fullText)
        : "";
    final message = widget.messageController.text;
    if (message.isNotEmpty) {
      setState(() {
        messages.add(ChatMessage(text: message, isUser: true));
        widget.messageController.clear();
      });
      _scrollToBottom();

      if (selectedApi == "GPT") {
        _getGPTResponse(fullText, selectedText, message);
      } else {
        _getGeminiResponse(fullText, selectedText, message);
      }
    }
  }

  void addMessage(String text) {
    setState(() {
      messages.add(ChatMessage(text: text, isUser: true));
      widget.messageController.text = "";
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _getGPTResponse(String fullText, String selectedText, String message) {
    gpt
        .getDetailedResponse(messages, fullText, selectedText, message)
        .then((response) {
      setState(() {
        if (response.contains("Full code:")) {
          int startIndex = response.indexOf("Full code:") + "Full code:".length;
          String newCode = response.substring(startIndex).trim();
          updateHighlightedText(newCode);
        }
        messages.add(ChatMessage(text: response, isUser: false));
        _scrollToBottom();
      });
    }).catchError((error) {
      setState(() {
        messages.add(ChatMessage(
            text: "Error retrieving the answer. Please try again later.",
            isUser: false));
        _scrollToBottom();
      });
    });
  }

  void _getGeminiResponse(
      String fullText, String selectedText, String message) {
    gemini
        .getDetailedResponse(messages, fullText, selectedText, message)
        .then((response) {
      setState(() {
        if (response != null && response.contains("Full code:")) {
          int startIndex = response.indexOf("Full code:") + "Full code:".length;
          String newCode = response.substring(startIndex).trim();
          updateHighlightedText(newCode);
        }
        messages.add(ChatMessage(text: response ?? "No answer", isUser: false));
        _scrollToBottom();
      });
    }).catchError((error) {
      setState(() {
        messages.add(ChatMessage(
            text: "Error retrieving the answer. Please try again later.",
            isUser: false));
        _scrollToBottom();
      });
    });
  }

  Future<void> _startListening() async {
    if (!_hasSpeech) {
      await _initSpeech();
    }
    if (_hasSpeech) {
      setState(() {
        _isListening = true;
      });
      _speech.listen(
        onResult: (val) {
          setState(() {
            _speechText = val.recognizedWords;
            widget.messageController.text += _speechText;
            if (val.finalResult) {
              _isListening = false; // Reset when final result is received
            }
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 10),
        partialResults: false,
        onSoundLevelChange: (level) => print("Sound level: $level"),
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  
  void updateHighlightedText(String newCode) {
    String originalText = widget.mainTextController.text;
    DiffMatchPatch dmp = DiffMatchPatch();

    List<Diff> diffs = dmp.diff(originalText, newCode);

    String highlightedText = '';

    for (Diff diff in diffs) {
      switch (diff.operation) {
        case DIFF_INSERT:
          highlightedText += '[green]' + diff.text + '[/green]';
          break;
        case DIFF_DELETE:
          highlightedText += '[red]' + diff.text + '[/red]';
          break;
        case DIFF_EQUAL:
          highlightedText += diff.text;
          break;
      }
    }

    setState(() {
      widget.mainTextController.text = highlightedText;
    });
    widget.onTextUpdated!();
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await flutterTts.stop(); 
    } else {
      await flutterTts.setLanguage("en-US");
      await flutterTts.setPitch(1.0);
      await flutterTts.speak(text); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: 15,
        right: 15,
      ),
      child: Column(
        children: <Widget>[
          // Dropdown-Menü für API-Auswahl
          DropdownButton<String>(
            value: selectedApi,
            items: const [
              DropdownMenuItem(value: "GPT", child: Text("GPT")),
              DropdownMenuItem(value: "Gemini", child: Text("Gemini")),
            ],
            onChanged: (value) {
              setState(() {
                selectedApi = value!;
              });
            },
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];

                // Rückgabewert für jede Nachricht
                return ListTile(
                  title: Align(
                    alignment: message.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: GestureDetector(
                      onLongPress: () {
                        // Nachricht in die Zwischenablage kopieren
                        Clipboard.setData(ClipboardData(text: message.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Message copied to clipboard!"),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 5.0),
                        decoration: BoxDecoration(
                          color: message.isUser
                              ? Colors.blue[100]
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SelectableText(
                          message.text,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          TextField(
            focusNode: widget.focusNode,
            controller: widget.messageController,
            onTap: () {
              if (!widget.normalKeyBoard) {
                widget.onToggleHandwriting(true);
              }
            },
            keyboardType: widget.normalKeyBoard
                ? TextInputType.multiline
                : TextInputType.none,
            decoration: InputDecoration(
              labelText: 'Send message',
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
              ),
            ),
            minLines: 1, 
            maxLines: 5, 
            onSubmitted: (value) => _sendMessage(),
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isListening ? _stopListening : _startListening,
                  child: Icon(_isListening ? Icons.stop : Icons.mic),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: messages.isNotEmpty
                      ? () => _speak(messages.last.text)
                      : null, 
                  child: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
