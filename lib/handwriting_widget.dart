import 'package:flutter/material.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as mlkit;

class HandwritingWidget extends StatefulWidget {
  final Function(String) onRecognized;
  final Function(bool) onToggleVisibility;
  final TextEditingController textController;

  const HandwritingWidget({super.key, 
    required this.onRecognized,
    required this.onToggleVisibility,
    required this.textController,
  });

  @override
  _HandwritingWidgetState createState() => _HandwritingWidgetState();
}

class _HandwritingWidgetState extends State<HandwritingWidget> {
  final recognizer = mlkit.DigitalInkRecognizer(languageCode: 'en-US');
  final modelManager = mlkit.DigitalInkRecognizerModelManager();
  List<mlkit.Stroke> strokes = [];

  @override
  void initState() {
    super.initState();
    _checkAndDownloadModel();
  }

  Future<void> _checkAndDownloadModel() async {
    const String modelTag = 'en-US';
    bool isDownloaded = await modelManager.isModelDownloaded(modelTag);
    if (!isDownloaded) {
      await modelManager.downloadModel(modelTag);
    }
  }

  void _insertSpaceAtCursor() {
    final text = widget.textController.text;
    final selection = widget.textController.selection;
    final newText = text.substring(0, selection.baseOffset) +
        ' ' +
        text.substring(selection.baseOffset);
    widget.textController.text = newText;
    widget.textController.selection = selection.copyWith(
      baseOffset: selection.baseOffset + 1,
      extentOffset: selection.baseOffset + 1,
    );
  }

  void _deleteLastCharacter() {
    final text = widget.textController.text;
    final selection = widget.textController.selection;
    if (selection.baseOffset > 0) {
      final newText = text.substring(0, selection.baseOffset - 1) +
          text.substring(selection.baseOffset);
      widget.textController.text = newText;
      widget.textController.selection = selection.copyWith(
        baseOffset: selection.baseOffset - 1,
        extentOffset: selection.baseOffset - 1,
      );
    }
  }

  void _insertNewLineAtCursor() {
    final text = widget.textController.text;
    final selection = widget.textController.selection;
    final newText = text.substring(0, selection.baseOffset) +
        '\n' +
        text.substring(selection.baseOffset);
    widget.textController.text = newText;
    widget.textController.selection = selection.copyWith(
      baseOffset: selection.baseOffset + 1,
      extentOffset: selection.baseOffset + 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey,
        title: const Text('Write here'),
        actions: [
          IconButton(
            icon: const Icon(Icons.space_bar),
            onPressed: _insertSpaceAtCursor,
            tooltip: 'Insert space',
          ),
          IconButton(
            icon: const Icon(Icons.backspace),
            onPressed: _deleteLastCharacter,
            tooltip: 'Delete last letter',
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_return),
            onPressed: _insertNewLineAtCursor,
            tooltip: 'Insert new line',
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              try {
                final ink = mlkit.Ink()..strokes = strokes;
                final candidates = await recognizer.recognize(ink);
                if (candidates.isNotEmpty) {
                  widget.onRecognized(candidates.first.text);
                  setState(() {
                    strokes.clear();
                  });
                }

                //Navigator.of(context).pop();
              } catch (e) {
                print("Error during recognition: $e");
              }
            },
            tooltip: 'Accept',
          ),
          IconButton(
            icon: const Icon(Icons.close), 
            onPressed: () {
              widget.onToggleVisibility(false); 
            },
            tooltip: 'Close Window',
          ),
        ],
      ),
      body: GestureDetector(
        onPanStart: (details) {
          setState(() {
            strokes.add(mlkit.Stroke()..points = []);
          });
        },
        onPanUpdate: (details) {
          setState(() {
            strokes.last.points.add(
              mlkit.StrokePoint(
                x: details.localPosition.dx,
                y: details.localPosition.dy,
                t: DateTime.now().millisecondsSinceEpoch,
              ),
            );
          });
        },
        onPanEnd: (details) {
          
        },
        child: CustomPaint(
          painter: _DrawingPainter(strokes),
          child: Container(),
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<mlkit.Stroke> strokes;

  _DrawingPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (var stroke in strokes) {
      for (int i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(
          Offset(stroke.points[i].x, stroke.points[i].y),
          Offset(stroke.points[i + 1].x, stroke.points[i + 1].y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
