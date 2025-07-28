import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:Sketchbot/chatBot_widget.dart';
import 'package:Sketchbot/file_drawer.dart';
import 'package:Sketchbot/gemini.dart';
import 'package:Sketchbot/handwriting_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'gpt.dart';
import 'package:path/path.dart' as path;

class MainWidget extends StatefulWidget {
  const MainWidget({super.key});

  @override
  MainWidgetScreen createState() => MainWidgetScreen();
}

class MainWidgetScreen extends State<MainWidget> {
  late TextEditingController _textEditingController;
  late TextEditingController _chatBotTextController;
  late FocusNode _focusNode;
  late FocusNode _chatBotFocusNode;
  List<List<Offset>> strokes = [];
  List<TextBox> textBoxes = [];
  List<TextRange> textBoxOffsets = [];
  bool showHandwritingWidget = false;
  bool drawMode = false;
  bool sketchMode = false;
  bool isChatVisible = false;
  bool normalKeyboardType = false;
  bool isTextSelected = false;
  bool isLoading = false;
  bool isRecording = false;
  Timer? _drawingTimer;
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final GlobalKey _textFieldKey = GlobalKey();
  String? currentFilePath;
  ChatBotWidget? chatBotWidget;
  final ScrollController _textScrollController = ScrollController();
  final ScrollController _lineNumberScrollController = ScrollController();
  List<String> fileList = [];
  Rect? boundingBox;
  TextPainter? painter;
  double additionalLeftPadding = 0;
  final double additionalTopPadding = 20;
  late EditableTextState? _editableTextState;
  List<String> _history = [];
  int _historyIndex = -1;

  List<Map<String, dynamic>> redIndices = [];
  List<Map<String, dynamic>> greenIndices = [];
  List<TextBox> diffRedTextBoxes = [];
  List<TextBox> diffGreenTextBoxes = [];

  bool _isFirstUpdate = true;

  final TextStyle textStyle = const TextStyle(
    color: Colors.black,
    fontSize: 14.0,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.normal,
    letterSpacing: 1.0,
    wordSpacing: 3.0,
    textBaseline: TextBaseline.alphabetic,
    height: 1.2,
    locale: Locale('en', 'US'),
    fontFamily: 'Sans-serif',
    decoration: TextDecoration.none,
    inherit: false,
  );

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController();
    _chatBotTextController = TextEditingController();
    _focusNode = FocusNode();
    _chatBotFocusNode = FocusNode();
    chatBotWidget = ChatBotWidget(
      mainTextController: _textEditingController,
      messageController: _chatBotTextController,
      onToggleHandwriting: toggleHandwritingVisibility,
      normalKeyBoard: normalKeyboardType,
      showHandwritingWidget: showHandwritingWidget,
      onTextUpdated: setStateForRerender,
    );

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        if (_isFirstUpdate) {
          _setCursorToBeginning();
          _isFirstUpdate = false;
        }
      }
    });

    _textEditingController.addListener(_onTextChanged);

    _textScrollController.addListener(() {
      if (_lineNumberScrollController.hasClients &&
          _lineNumberScrollController.offset != _textScrollController.offset) {
        _lineNumberScrollController.jumpTo(_textScrollController.offset);
      }
    });

    _lineNumberScrollController.addListener(() {
      if (_textScrollController.hasClients &&
          _textScrollController.offset != _lineNumberScrollController.offset) {
        _textScrollController.jumpTo(_lineNumberScrollController.offset);
      }
    });
  }

  void _setCursorToBeginning() {
    _textEditingController.selection = const TextSelection.collapsed(offset: 0);
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _focusNode.dispose();
    _textScrollController.dispose();
    _lineNumberScrollController.dispose();
    _drawingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    if (_history.isEmpty || _textEditingController.text != _history.last) {
      _history.add(_textEditingController.text);
      _historyIndex++;
    }
  }

  void setStateForRerender() {
    setState(() {});
  }

  void _undoLastAction() {
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        _textEditingController.text = _history[_historyIndex];
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Last action undone!"),
        duration: Duration(seconds: 2),
      ));
    }
  }

  void collectTextBoxes() {
    double screenWidth = MediaQuery.of(context).size.width;
    double scrollOffset = _textScrollController.offset;
    RegExp nonWhitespaceRegExp = RegExp(r'\S');
    painter = TextPainter(
      text: TextSpan(text: _textEditingController.text, style: textStyle),
      textDirection: TextDirection.ltr,
      textScaleFactor: MediaQuery.of(context).textScaleFactor,
      maxLines: null,
    );
    painter!
        .layout(maxWidth: screenWidth * 20 / (isChatVisible ? 34 : 26) - 40);
    additionalLeftPadding = 20 + (screenWidth * 6 / (isChatVisible ? 34 : 26));
    textBoxes = [];
    textBoxOffsets = [];
    for (var i = 0; i < _textEditingController.text.length; i++) {
      int start = i;
      if (nonWhitespaceRegExp.hasMatch(_textEditingController.text[i]) ==
          true) {
        while (i < _textEditingController.text.length &&
            nonWhitespaceRegExp.hasMatch(_textEditingController.text[i++]) ==
                true) {
          ;
        }
        i--;
        textBoxOffsets.add(TextRange(start: start, end: i));
        List<TextBox> textBoxes = painter!.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: i),
        );
        if (textBoxes.isNotEmpty) {
          Rect rect = textBoxes[0].toRect();
          Offset topLeft = rect.topLeft -
              Offset(0, scrollOffset) +
              Offset(additionalLeftPadding, additionalTopPadding);
          Offset bottomRight = rect.bottomRight -
              Offset(0, scrollOffset) +
              Offset(additionalLeftPadding, additionalTopPadding);
          textBoxes.add(TextBox.fromLTRBD(topLeft.dx, topLeft.dy,
              bottomRight.dx, bottomRight.dy, TextDirection.ltr));
        }
      }
    }
  }

  void collectDiff(String mainText) {
    RegExp tagExp = RegExp(r'\[(red|green)\]([\s\S]*?)\[/\1\]');
    int adjustment = 0;
    redIndices.clear();
    greenIndices.clear();
    Iterable<RegExpMatch> matches = tagExp.allMatches(mainText);
    for (var match in matches) {
      String tag = match.group(1)!;
      String content = match.group(2)!;
      int startIndex = match.start - adjustment;
      int endIndex = startIndex + content.length;

      if (tag == 'red') {
        redIndices.add({
          "content": content,
          "startIndex": startIndex,
          "endIndex": endIndex,
        });
      } else if (tag == 'green') {
        greenIndices.add({
          "content": content,
          "startIndex": startIndex,
          "endIndex": endIndex,
        });
      }
      adjustment += tag.length * 2 + 5;
    }
    _textEditingController.text = mainText.replaceAll(
        RegExp(r'\[red\]|\[/red\]|\[green\]|\[/green\]'), '');

    setDiffRect();
  }

  void setDiffRect() {
    double screenWidth = MediaQuery.of(context).size.width;

    diffRedTextBoxes.clear();
    diffGreenTextBoxes.clear();

    painter = TextPainter(
      text: TextSpan(text: _textEditingController.text, style: textStyle),
      textDirection: TextDirection.ltr,
      textScaleFactor: MediaQuery.of(context).textScaleFactor,
      maxLines: null,
    );
    painter!
        .layout(maxWidth: screenWidth * 20 / (isChatVisible ? 34 : 26) - 40);

    for (int i = 0; i < redIndices.length; i++) {
      List<TextBox> textBoxes = painter!.getBoxesForSelection(
        TextSelection(
            baseOffset: redIndices[i]['startIndex'],
            extentOffset: redIndices[i]['endIndex']),
      );

      for (TextBox box in textBoxes) {
        Rect rect = box.toRect();

        Offset topLeft = rect.topLeft + Offset(20, additionalTopPadding);
        Offset bottomRight =
            rect.bottomRight + Offset(20, additionalTopPadding);

        diffRedTextBoxes.add(TextBox.fromLTRBD(topLeft.dx, topLeft.dy,
            bottomRight.dx, bottomRight.dy, TextDirection.ltr));
      }
    }

    for (int i = 0; i < greenIndices.length; i++) {
      List<TextBox> textBoxes0 = painter!.getBoxesForSelection(
        TextSelection(
            baseOffset: greenIndices[i]['startIndex'],
            extentOffset: greenIndices[i]['endIndex']),
      );

      for (TextBox box in textBoxes0) {
        Rect rect = box.toRect();

        Offset topLeft = rect.topLeft + Offset(20, additionalTopPadding);
        Offset bottomRight =
            rect.bottomRight + Offset(20, additionalTopPadding);

        diffGreenTextBoxes.add(TextBox.fromLTRBD(topLeft.dx, topLeft.dy,
            bottomRight.dx, bottomRight.dy, TextDirection.ltr));
      }
    }
  }

  void _showPopupMenu(
      BuildContext context, Offset position, String color, int index) async {
    final selected = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        const PopupMenuItem<String>(
          value: 'accept',
          child: Text('Accept'),
        ),
        const PopupMenuItem<String>(
          value: 'decline',
          child: Text('Decline'),
        ),
      ],
    );

    if (selected == 'accept') {
      _handleAccept(color, index);
    } else if (selected == 'decline') {
      _handleDecline(color, index);
    }
  }

  void _handleAccept(String color, int index) {
    setState(() {
      if (color == "red") {
        String before = _textEditingController.text
            .substring(0, redIndices[index]['startIndex']);
        String after = _textEditingController.text
            .substring(redIndices[index]['endIndex']);
        int removedLength =
            redIndices[index]['endIndex'] - redIndices[index]['startIndex'];

        _textEditingController.text = before + after;

        for (int i = index + 1; i < redIndices.length; i++) {
          redIndices[i]['startIndex'] -= removedLength;
          redIndices[i]['endIndex'] -= removedLength;
        }

        for (int i = 0; i < greenIndices.length; i++) {
          if (greenIndices[i]['startIndex'] > redIndices[index]['endIndex']) {
            greenIndices[i]['startIndex'] -= removedLength;
            greenIndices[i]['endIndex'] -= removedLength;
          }
        }

        redIndices.removeAt(index);
      } else if (color == "green") {
        greenIndices.removeAt(index);
      }

      setDiffRect();
    });
  }

  void _handleDecline(String color, int index) {
    if (color == "green" && index < greenIndices.length) {
      final startIndex = greenIndices[index]['startIndex'];
      final endIndex = greenIndices[index]['endIndex'];
      final adjustment = greenIndices[index]['content'].length;

      _textEditingController.text =
          _textEditingController.text.substring(0, startIndex) +
              _textEditingController.text.substring(endIndex);

      for (int i = index + 1; i < greenIndices.length; i++) {
        greenIndices[i]['startIndex'] -= adjustment;
        greenIndices[i]['endIndex'] -= adjustment;
      }

      for (int i = 0; i < redIndices.length; i++) {
        if (redIndices[i]['startIndex'] > endIndex) {
          redIndices[i]['startIndex'] -= adjustment;
          redIndices[i]['endIndex'] -= adjustment;
        }
      }

      greenIndices.removeAt(index);
    } else if (color == "red" && index < redIndices.length) {
      redIndices.removeAt(index);
    }

    setDiffRect();
  }

  void clearDiff() {
    if (redIndices.isNotEmpty) {
      redIndices.clear();
    }
    if (greenIndices.isNotEmpty) {
      int adjustment = 0;
      for (int i = 0; i < greenIndices.length; i++) {
        _textEditingController.text = _textEditingController.text
                .substring(0, greenIndices[i]['startIndex'] - adjustment) +
            _textEditingController.text
                .substring(greenIndices[i]['endIndex'] - adjustment);

        int _adjust = greenIndices[i]['content'].length;
        adjustment += _adjust;
      }
      greenIndices.clear();
    }

    setState(() {
      diffRedTextBoxes.clear();
      diffGreenTextBoxes.clear();
    });
  }

  void acceptAllChanges() {
    setState(() {
      // Akzeptiere alle roten Änderungen
      while (redIndices.isNotEmpty) {
        _handleAccept("red",
            0); // Starte immer bei Index 0, da die Liste nach jeder Akzeptanz aktualisiert wird
      }

      // Akzeptiere alle grünen Änderungen
      while (greenIndices.isNotEmpty) {
        _handleAccept("green",
            0); // Starte immer bei Index 0, da die Liste nach jeder Akzeptanz aktualisiert wird
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("All changes accepted!"),
      duration: Duration(seconds: 2),
    ));
  }

  void declineAllChanges() {
    setState(() {
      // Ablehnen aller roten Änderungen
      while (redIndices.isNotEmpty) {
        if (redIndices.length > 0) {
          _handleDecline("red", 0); // Immer den ersten Index bearbeiten
        } else {
          break;
        }
      }

      // Ablehnen aller grünen Änderungen
      while (greenIndices.isNotEmpty) {
        if (greenIndices.length > 0) {
          _handleDecline("green", 0); // Immer den ersten Index bearbeiten
        } else {
          break;
        }
      }

      // Nach dem Ablehnen: Alle Kästen und Indizes löschen
      diffRedTextBoxes.clear();
      diffGreenTextBoxes.clear();
      redIndices.clear();
      greenIndices.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("All changes declined!"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool get hasChanges => redIndices.isNotEmpty || greenIndices.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_textEditingController.text.isNotEmpty &&
        _textEditingController.selection.isValid) {
      int start = _textEditingController.selection.start;
      int end = _textEditingController.selection.end;

      if (start >= 0 &&
          end > start &&
          end <= _textEditingController.text.length) {
        isTextSelected = true;
      }
    }

    if (_textEditingController.text.isNotEmpty) {
      String mainText = _textEditingController.text;

      if (mainText.contains("[red]") || mainText.contains("[green]")) {
        collectDiff(mainText);
      }
    }

    List<Widget> diffRect = [];

    for (int i = 0; i < diffRedTextBoxes.length; i++) {
      diffRect.add(
        Positioned(
          left: diffRedTextBoxes[i].left,
          top: diffRedTextBoxes[i].top,
          child: GestureDetector(
            onTapDown: (TapDownDetails details) {
              final Offset tapPosition = details.globalPosition;

              _showPopupMenu(context, tapPosition, "red", i);
            },
            child: Container(
              width: diffRedTextBoxes[i].right - diffRedTextBoxes[i].left,
              height: diffRedTextBoxes[i].bottom - diffRedTextBoxes[i].top,
              color: Colors.red.withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    for (int i = 0; i < diffGreenTextBoxes.length; i++) {
      diffRect.add(
        Positioned(
          left: diffGreenTextBoxes[i].left,
          top: diffGreenTextBoxes[i].top,
          child: GestureDetector(
            onTapDown: (TapDownDetails details) {
              final Offset tapPosition = details.globalPosition;

              _showPopupMenu(context, tapPosition, "green", i);
            },
            child: Container(
              width: diffGreenTextBoxes[i].right - diffGreenTextBoxes[i].left,
              height: diffGreenTextBoxes[i].bottom - diffGreenTextBoxes[i].top,
              color: Colors.green.withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (hasChanges)
            Center(
              child: ElevatedButton(
                onPressed: () {
                  acceptAllChanges();
                },
                child: const Text('Accept all changes!'),
              ),
            ),
          if (hasChanges)
            Center(
              child: ElevatedButton(
                onPressed: () {
                  declineAllChanges();
                },
                child: const Text('Decline all changes!'),
              ),
            ),
          if (sketchMode)
            Center(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    drawMode = !drawMode;
                    sketchMode = !sketchMode;
                  });
                  strokes.clear();
                },
                child: const Text('Cancel Sketch'),
              ),
            ),
          Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  if (!drawMode) {
                    collectTextBoxes();
                  }
                  drawMode = !drawMode;
                  sketchMode = !sketchMode;
                });

                if (!drawMode) {
                  print(strokes);
                  _handleDrawingResult();
                  strokes.clear();
                }
                setStateForRerender();
                FocusScope.of(context).requestFocus(_focusNode);
              },
              child: Text(sketchMode ? 'Finish Sketch' : 'Sketch'),
            ),
          ),
          IconButton(
              icon: Icon(drawMode ? Icons.edit : Icons.brush),
              onPressed: handleDrawingToggle),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveCurrentTextToFile,
          ),
          IconButton(
            icon:
                Icon(normalKeyboardType ? Icons.keyboard : Icons.keyboard_hide),
            onPressed: () {
              setState(() {
                normalKeyboardType = !normalKeyboardType;
                if (_focusNode.hasFocus) {
                  _focusNode.unfocus();
                }
                if (normalKeyboardType) {
                  showHandwritingWidget = false;
                }
                Future.delayed(const Duration(milliseconds: 100), () {
                  FocusScope.of(context).requestFocus(_focusNode);
                });
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              setState(() {
                isChatVisible = !isChatVisible;
              });
            },
          ),
          IconButton(icon: const Icon(Icons.undo), onPressed: _undoLastAction),
          // Dieser Button ist für die Video Aufzeichnung. Wir machen jetzt aber externe Aufzeichnung
          /* IconButton(
            icon: Icon(_isRecording ? Icons.stop : Icons.videocam),
            onPressed: () {
              if (_isRecording) {
                _stopScreenRecording();
              } else {
                _startScreenRecording();
              }
            },
          ), */
        ],
      ),
      body: RepaintBoundary(
        key: _repaintBoundaryKey,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                bottom: showHandwritingWidget ? 220 : 0,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: FileDrawer(
                      onFileSelected: _loadFile,
                      onFileListUpdated: _updateFileList,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Scrollbar(
                        controller: _lineNumberScrollController,
                        child: ListView.builder(
                          controller: _lineNumberScrollController,
                          itemCount:
                              _textEditingController.text.split('\n').length +
                                  25,
                          itemBuilder: (context, index) {
                            return Container(
                              child: Text(
                                '${index + 1}',
                                style: textStyle,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 20,
                    child: Stack(
                      children: [
                        Scrollbar(
                          controller: _textScrollController,
                          child: SingleChildScrollView(
                            controller: _textScrollController,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight:
                                      MediaQuery.of(context).size.height),
                              child: Stack(
                                children: [
                                  TextField(
                                    key: _textFieldKey,
                                    focusNode: _focusNode,
                                    controller: _textEditingController,
                                    decoration: const InputDecoration(
                                        hintText: 'Text here...',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.all(20.0)),
                                    maxLines: null,
                                    textAlignVertical: TextAlignVertical.top,
                                    enableInteractiveSelection: true,
                                    keyboardType: normalKeyboardType
                                        ? TextInputType.multiline
                                        : TextInputType.none,
                                    style: textStyle,
                                    onTap: () {
                                      setState(() {
                                        if (!normalKeyboardType) {
                                          showHandwritingWidget = true;
                                        }
                                      });
                                    },
                                    onChanged: (text) {
                                      clearDiff();
                                    },
                                    contextMenuBuilder:
                                        (context, editableTextState) {
                                      _editableTextState = editableTextState;
                                      final List<ContextMenuButtonItem>
                                          buttonItems = editableTextState
                                              .contextMenuButtonItems;
                                      buttonItems.insert(
                                        0,
                                        ContextMenuButtonItem(
                                          label: 'Sketch',
                                          onPressed: () {
                                            setState(() {
                                              drawMode = !drawMode;
                                              sketchMode = !sketchMode;
                                            });
                                            if (!drawMode) {
                                              _handleDrawingResult();
                                              strokes.clear();
                                            }
                                          },
                                        ),
                                      );
                                      return AdaptiveTextSelectionToolbar
                                          .buttonItems(
                                        anchors: editableTextState
                                            .contextMenuAnchors,
                                        buttonItems: buttonItems,
                                      );
                                    },
                                  ),
                                  ...diffRect
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isChatVisible)
                    Expanded(
                      flex: 8,
                      child: ChatBotWidget(
                        mainTextController: _textEditingController,
                        messageController: _chatBotTextController,
                        focusNode: _chatBotFocusNode,
                        onToggleHandwriting: toggleHandwritingVisibility,
                        normalKeyBoard: normalKeyboardType,
                        showHandwritingWidget: showHandwritingWidget,
                        onTextUpdated: setStateForRerender,
                      ),
                    ),
                ],
              ),
            ),
            if (drawMode)
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      strokes.add([details.localPosition]);
                    });
                    if (!sketchMode && _drawingTimer != null) {
                      _drawingTimer!.cancel();
                    }
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      strokes.last.add(details.localPosition);
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {});
                    if (!sketchMode) {
                      _drawingTimer?.cancel();
                      _drawingTimer =
                          Timer(const Duration(milliseconds: 500), () {
                        handleDrawingToggle();
                      });
                    }
                  },
                  child: CustomPaint(
                    painter: DrawPainter(strokes, textBoxes,
                        boundingBox: boundingBox),
                  ),
                ),
              ),
            if (showHandwritingWidget && !normalKeyboardType)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 200,
                child: HandwritingWidget(
                  onRecognized: (text) {
                    if (_chatBotFocusNode.hasFocus) {
                      setState(() {
                        _chatBotTextController.text += text;
                        _chatBotTextController.selection =
                            TextSelection.fromPosition(
                          TextPosition(
                              offset: _chatBotTextController.text.length),
                        );
                        showHandwritingWidget = false;
                        print("Der text im message controller: " +
                            _chatBotTextController.text);
                      });
                    } else {
                      int cursorPos =
                          _textEditingController.selection.baseOffset;
                      String newText = text;
                      if (cursorPos != -1) {
                        String beforeText =
                            _textEditingController.text.substring(0, cursorPos);
                        String afterText =
                            _textEditingController.text.substring(cursorPos);
                        newText = beforeText + text + afterText;
                        _textEditingController.text = newText;
                        _textEditingController.selection =
                            TextSelection.fromPosition(
                          TextPosition(offset: cursorPos + text.length),
                        );
                      }
                    }
                  },
                  onToggleVisibility: toggleHandwritingVisibility,
                  textController: _chatBotFocusNode.hasFocus
                      ? _chatBotTextController
                      : _textEditingController,
                ),
              ),
            if (isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        'Processing your sketch, please wait...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void handleDrawingToggle() {
    _focusNode.requestFocus();
    setCursorToFirstVisibleText();

    if (drawMode) {
      markCircledText();
    }

    setState(() {
      drawMode = !drawMode;
      if (!drawMode) {
        strokes.clear();
      } else {
        collectTextBoxes();
      }
    });
  }

  void _loadFile(String path) async {
    String content = await File(path).readAsString();
    setState(() {
      _textEditingController.text = content;
      currentFilePath = path;
    });
  }

  void _updateFileList(List<String> files) {
    setState(() {
      fileList = files;
    });
  }

  void _saveCurrentTextToFile() async {
    if (currentFilePath == null) {
      return;
    }
    final File file = File(currentFilePath!);
    await file.writeAsString(_textEditingController.text);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("File saved successfully!"),
      duration: Duration(seconds: 2),
    ));
  }

  Future<String> _processDrawing() async {
    RenderRepaintBoundary? boundary = _repaintBoundaryKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        File imgFile = await _saveImage(pngBytes);
        return _sendImageToGPT(imgFile);
      }
    }
    return 'leer';
  }

  Future<File> _saveImage(Uint8List bytes) async {
    Directory tempDir = await getTemporaryDirectory();
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    File file = File('${tempDir.path}/temp_image_$fileName.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<String> _sendImageToGPT(File imageFile) async {
    try {
      GPT gpt = GPT();
      String response = await gpt.sendImageAndGetResponse(imageFile);
      return response;
    } catch (e) {
      print('Error sending image to GPT: $e');
      return 'leer';
    }
  }

  Future<void> _handleDrawingResult() async {
    setState(() {
      isLoading = true;
    });
    String drawingResult = await _processDrawing();

    if (drawingResult == "Cross") {
      if (isTextSelected) {
        _deleteSelectedText();
      } else {
        _showNoTextSelectedMessage();
      }
    } else if (drawingResult == "Question mark") {
      if (isTextSelected) {
        String fullText = _textEditingController.text;
        String selectedText =
            _textEditingController.selection.textInside(fullText);
        try {
          String? explanation = await GeminiChatBot()
              .explainCodeWithGemini(fullText, selectedText);
          _showAlertDialog(context, explanation!);
        } catch (e) {
          print("Error: $e");
        }
      } else {
        _showNoTextSelectedMessage();
      }
    } else if (drawingResult == "Letter R") {
      if (isTextSelected) {
        _renameSelectedText();
      } else {
        _showNoTextSelectedMessage();
      }
    } else if (drawingResult == "Letter V") {
      if (isTextSelected) {
        _insertCopiedText();
      } else {
        _showNoTextSelectedMessage();
      }
    } else if (drawingResult == "Letter C") {
      if (isTextSelected) {
        _copySelectedText();
      } else {
        _showNoTextSelectedMessage();
      }
    } else if (drawingResult == "Two lines") {
      if (isTextSelected) {
        _commentOutSelectedText();
      } else {
        _showNoTextSelectedMessage();
      }
    } else if (drawingResult.startsWith("Arrow +")) {
      if (isTextSelected) {
        int fileIndex =
            int.parse(drawingResult.substring("Arrow + ".length).trim());
        if (fileIndex >= 1 && fileIndex <= fileList.length) {
          String fileName = fileList[fileIndex - 1];
          print(fileName);
          _appendTextToFile(fileName);
        }
      } else {
        _showNoTextSelectedMessage();
      }
    } else if (drawingResult == "Letter Z") {
      _undoLastAction();
    } else if (drawingResult == "Heart") {
      _formatText();
    } else {
      // Dialog anzeigen, wenn keine bekannte Zeichnung erkannt wurde
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Unrecognized Drawing"),
            content: const Text("The drawing you made is not recognized."),
            actions: [
              ElevatedButton(
                child: const Text("Close"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
    setState(() {
      isLoading = false; // Ladeindikator anzeigen
    });
  }

  void _showNoTextSelectedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please select a text first!"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _formatText() async {
    String originalCode = _textEditingController.text;

    // Zeige den Dialog mit dem CircularProgressIndicator
    showDialog(
      context: context,
      barrierDismissible:
          false, // Dialog nicht durch Klicken außerhalb schließen
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Formatting text, please wait..."),
            ],
          ),
        );
      },
    );

    try {
      // Formatiere den Code mit der API
      GeminiChatBot gemini = GeminiChatBot();
      String formattedCode = await gemini.formatCode(originalCode);

      setState(() {
        _textEditingController.text = formattedCode;
      });

      // Dialog schließen, nachdem der Prozess abgeschlossen ist
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Text successfully formatted!"),
        duration: Duration(seconds: 2),
      ));
    } catch (e) {
      // Dialog schließen und Fehler ausgeben, wenn ein Fehler auftritt
      Navigator.of(context).pop();
      print('Error formatting code: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Error formatting text."),
        duration: Duration(seconds: 2),
      ));
    }
  }

  Future<void> _appendTextToFile(String fileName) async {
    String fullText = _textEditingController.text;
    String selectedText = _textEditingController.selection.textInside(fullText);

    if (selectedText.isNotEmpty) {
      final File file = File(fileName);

      await file.writeAsString(selectedText, mode: FileMode.append);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Text successfully attached to the file!"),
        duration: Duration(seconds: 2),
      ));
    }
    _deleteSelectedText();
  }

  Future<void> _insertCopiedText() async {
    ClipboardData? clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null && clipboardData.text != null) {
      final String clipboardText = clipboardData.text!;
      print("copied text" + clipboardText.toString());
      final String fullText = _textEditingController.text;
      final TextSelection selection = _textEditingController.selection;

      final int start = selection.start;
      final int end = selection.end;

      final String newText = fullText.replaceRange(start, end, clipboardText);

      setState(() {
        _textEditingController.text = newText;
        _textEditingController.selection =
            TextSelection.collapsed(offset: start + clipboardText.length);
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Copied text successfully inserted!"),
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _copySelectedText() async {
    String fullText = _textEditingController.text;
    String selectedText = _textEditingController.selection.textInside(fullText);

    if (selectedText.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: selectedText));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Text successfully copied!"),
        duration: Duration(seconds: 2),
      ));
    }
  }

  void toggleHandwritingVisibility(bool isVisible) {
    setState(() {
      showHandwritingWidget = isVisible;
    });
  }

  Future<void> _renameSelectedText() async {
    String fullText = _textEditingController.text;
    String selectedText = _textEditingController.selection.textInside(fullText);

    // Überprüfen, ob der ausgewählte Text mehrere Zeilen umfasst
    if (selectedText.contains('\n')) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Invalid Selection"),
            content: const Text(
                "Please select a single variable or text item. Multi-line selections are not supported."),
            actions: <Widget>[
              ElevatedButton(
                child: const Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    // Entferne unerwünschte Zeichen wie Klammern, Punkte, Semikolon usw.
    String sanitizedText = selectedText.replaceAll(RegExp(r'[^\w\d_]'), '');
    if (sanitizedText.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Invalid Selection"),
            content: const Text(
                "The selected text is invalid. Please select a valid variable or identifier."),
            actions: <Widget>[
              ElevatedButton(
                child: const Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    double scrollOffset = _textScrollController.offset;
    TextSelection previousSelection = _textEditingController.selection;

    String? newName = await _showRenameDialog();
    if (newName != null && newName.isNotEmpty) {
      String newText = fullText.replaceAll(sanitizedText, newName);
      setState(() {
        _textEditingController.text = newText;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _textScrollController.jumpTo(scrollOffset);
        _textEditingController.selection = previousSelection;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Text successfully renamed!"),
        duration: Duration(seconds: 2),
      ));
    }
  }

  Future<String?> _showRenameDialog() async {
    TextEditingController renameController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename variable'),
          content: TextField(
            controller: renameController,
            decoration: const InputDecoration(hintText: 'New name'),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop(renameController.text);
              },
            ),
          ],
        );
      },
    );
  }

  void _commentOutSelectedText() {
    String fullText = _textEditingController.text;
    TextSelection selection = _textEditingController.selection;

    if (selection.isCollapsed) {
      return;
    }

    int start = selection.start;
    int end = selection.end;
    String selectedText = fullText.substring(start, end);
    List<String> selectedLines = selectedText.split('\n');
    List<String> commentedLines =
        selectedLines.map((line) => '// $line').toList();
    String commentedText = commentedLines.join('\n');

    String newText = fullText.replaceRange(start, end, commentedText);

    setState(() {
      _textEditingController.text = newText;
      _textEditingController.selection = TextSelection(
        baseOffset: start,
        extentOffset: start + commentedText.length,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Text successfully commented out!"),
      duration: Duration(seconds: 2),
    ));
  }

  //Das war dafür gedacht, um den Sketch zunächst zu bestätigen bevor es analysiert wird
  Future<bool> _showImageConfirmationDialog(File imageFile) async {
    return (await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Confirm the sketch!"),
              content: Image.file(imageFile),
              actions: <Widget>[
                ElevatedButton(
                  child: const Text("Confirm"),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
                ElevatedButton(
                  child: const Text("Cancel"),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            );
          },
        )) ??
        false;
  }

  void setCursorToFirstVisibleText() {
    final double scrollOffset =
        _textScrollController.offset; // Aktuelle Scroll-Position
    final double screenWidth = MediaQuery.of(context).size.width;

    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: _textEditingController.text, style: textStyle),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: screenWidth - 40);

    for (int i = 0; i < _textEditingController.text.length; i++) {
      final Offset caretOffset =
          textPainter.getOffsetForCaret(TextPosition(offset: i), Rect.zero);

      if (caretOffset.dy >= scrollOffset) {
        _textEditingController.selection = TextSelection.collapsed(offset: i);
        break;
      }
    }
  }

  void _showAlertDialog(BuildContext context, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Explanation"),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteSelectedText() {
    if (!_textEditingController.selection.isCollapsed) {
      int start = _textEditingController.selection.start;
      int end = _textEditingController.selection.end;
      String newText = _textEditingController.text.substring(0, start) +
          _textEditingController.text.substring(end);
      TextSelection newSelection = TextSelection.collapsed(offset: start);

      setState(() {
        _textEditingController.value = TextEditingValue(
          text: newText,
          selection: newSelection,
        );
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Text successfully deleted!"),
      duration: Duration(seconds: 2),
    ));
  }

  String getSelectedText() {
    return _textEditingController.selection
        .textInside(_textEditingController.text);
  }

  String getFullText() {
    return _textEditingController.text;
  }

  bool _isPointInPolygon(Offset point, List<Offset> polygon) {
    int count = 0;
    for (int i = 0; i < polygon.length; i++) {
      Offset p1 = polygon[i];
      Offset p2 = polygon[(i + 1) % polygon.length];

      if (point.dy > min(p1.dy, p2.dy) &&
          point.dy <= max(p1.dy, p2.dy) &&
          point.dx <= max(p1.dx, p2.dx) &&
          p1.dy != p2.dy) {
        double xinters =
            (point.dy - p1.dy) * (p2.dx - p1.dx) / (p2.dy - p1.dy) + p1.dx;
        if (p1.dx == p2.dx || point.dx <= xinters) {
          count++;
        }
      }
    }
    return (count % 2) != 0;
  }

  void markCircledText() {
    // Nur weitermachen, wenn es tatsächlich Strokes gibt
    if (strokes.isEmpty) return;

    // Berechnen der Bounding Box basierend auf den aktuellen Strokes
    double minX =
        strokes.expand((stroke) => stroke).map((p) => p.dx).reduce(min);
    double minY =
        strokes.expand((stroke) => stroke).map((p) => p.dy).reduce(min);
    double maxX =
        strokes.expand((stroke) => stroke).map((p) => p.dx).reduce(max);
    double maxY =
        strokes.expand((stroke) => stroke).map((p) => p.dy).reduce(max);

    // Setzen der globalen Bounding Box Variable
    boundingBox = Rect.fromLTRB(minX, minY, maxX, maxY);
    List<Offset> polygon = strokes.expand((stroke) => stroke).toList();

    int baseOffset = _textEditingController.text.length;
    int extentOffset = 0;

    // Überprüfen, ob TextBoxen innerhalb der Bounding Box liegen
    textBoxes.asMap().forEach((index, box) {
      Rect rect = box.toRect();
      List<Offset> rectPoints = [
        rect.topLeft,
        rect.topRight,
        rect.bottomRight,
        rect.bottomLeft
      ];

      for (double i = rect.topLeft.dx; i < rect.topRight.dx; i++) {
        rectPoints.add(Offset(i, rect.topLeft.dy));
        rectPoints.add(Offset(i, rect.bottomLeft.dy));
      }

      for (double i = rect.topLeft.dy; i < rect.bottomLeft.dy; i++) {
        rectPoints.add(Offset(rect.topLeft.dx, i));
        rectPoints.add(Offset(rect.topRight.dx, i));
      }

      if (rectPoints.any((point) => _isPointInPolygon(point, polygon))) {
        baseOffset = min(baseOffset, textBoxOffsets[index].start);
        extentOffset = max(extentOffset, textBoxOffsets[index].end);
      }
    });

    // Setzen der Textauswahl, wenn gültige TextBoxen gefunden wurden
    if (baseOffset < extentOffset) {
      _focusNode.requestFocus();

      _textEditingController.selection = TextSelection(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
      );

      setState(() {
        if (_editableTextState != null) _editableTextState!.showToolbar();
      });
    } else {
      setState(() {
        _textEditingController.selection =
            const TextSelection.collapsed(offset: 0);
      });
    }
  }

  //wird nicht verwendet, da wir externe Bildschirmaufnahme verwenden
  Future<void> _startScreenRecording() async {
    final TextEditingController nameController = TextEditingController();

    // Dialogfenster zur Eingabe des Dateinamens
    String? enteredName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Enter File Name"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: "Recording Name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            TextButton(
              child: const Text("Start Recording"),
              onPressed: () {
                Navigator.of(context).pop(nameController.text);
              },
            ),
          ],
        );
      },
    );

    // Abbruch, wenn kein Name eingegeben wurde
    if (enteredName == null || enteredName.isEmpty) {
      return;
    }

    // Erstelle den Dateinamen basierend auf Datum, Uhrzeit und Eingabenamen
    DateTime now = DateTime.now();
    String fileName =
        '${enteredName}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    bool started = await FlutterScreenRecording.startRecordScreen(
      fileName,
      titleNotification: "Recording Screen",
      messageNotification: "Screen recording in progress",
    );

    if (started) {
      setState(() {
        isRecording = true;
      });
    }
  }

  //wird nicht verwendet, da wir externe Bildschirmaufnahme verwenden
  Future<void> _stopScreenRecording() async {
    // Rückgabewert ist ein String (der Pfad zum gespeicherten Video im Cache)
    String? cacheFilePath = await FlutterScreenRecording.stopRecordScreen;

    if (cacheFilePath.isNotEmpty) {
      File videoFile = File(cacheFilePath);

      // Prüfen, ob die Datei existiert
      if (await videoFile.exists()) {
        try {
          // Speichere das Video im öffentlichen Movies-Verzeichnis
          Directory? moviesDirectory = Directory('/storage/emulated/0/Movies');
          String newFilePath =
              path.join(moviesDirectory.path, path.basename(cacheFilePath));

          // Kopiere das Video in den Movies-Ordner
          await videoFile.copy(newFilePath);

          setState(() {
            isRecording = false;
          });

          print("Screen recording saved successfully at: $newFilePath");
        } catch (e) {
          print("Error saving file to Movies directory: $e");
        }
      } else {
        print("Video file does not exist.");
      }
    } else {
      print("Screen recording failed.");
    }
  }
}

class DrawPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<TextBox> textBoxes;
  final Rect? boundingBox;

  DrawPainter(this.strokes, this.textBoxes, {this.boundingBox});

  @override
  void paint(Canvas canvas, ui.Size size) {
    Paint strokePaint = Paint()
      ..color = Colors.blue
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (var stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], strokePaint);
      }
    }

    Paint boxPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var box in textBoxes) {
      canvas.drawRect(box.toRect(), boxPaint);
    }

    // if (boundingBox != null) {
    // Paint boundingBoxPaint = Paint()
    //    ..color = Colors.green
    //      ..style = PaintingStyle.stroke
//        ..strokeWidth = 3.0;
//      canvas.drawRect(boundingBox!, boundingBoxPaint);
//    }
  }

  @override
  bool shouldRepaint(covariant DrawPainter oldDelegate) {
    return true;
  }
}
