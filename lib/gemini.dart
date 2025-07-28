import 'dart:convert';
import 'dart:io';
import 'package:Sketchbot/chatBot_widget.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiChatBot {
  GenerativeModel? model;

  GeminiChatBot() {
    model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: "PASTE-KEY-HERE");
  }

  Future<String?> getDetailedResponse(List<ChatMessage> messages,
      String fullText, String selectedText, String message) async {
    if (model == null) {
      return "Modell ist nicht initialisiert.";
    }

    List<Content> contents = messages.map((msg) {
      return msg.isUser
          ? Content.text(msg.text)
          : Content.model([TextPart(msg.text)]);
    }).toList();

    contents.add(Content.text(message));
    contents.add(Content.text("Here is the complete code: $fullText"));

    if (selectedText.isNotEmpty) {
      contents.add(Content.text("Here is the selected code: $selectedText"));
    }

    contents.add(Content.text(
        "You are a virtual assistant who helps developers in an IDE. "
        "You have two tasks and should only fulfill one of the two tasks for each message. "
        "First task: You answer the user's questions about the source code in human language and as short as possible. Also you answer in the language you are asked. "
        "Second task: You carry out the user's desired code change. "
        "When you perform the second task, your output always only starts with: 'Full code:' Then you only give the complete source code without additional explanations."));

    var chat = model!.startChat(history: contents);
    var response = await chat.sendMessage(Content.text(message));

    return response.text;
  }

  // Neue Methode: Bild verarbeiten und Muster interpretieren
  Future<String?> analyzeImageAndDetectPattern(File imageFile) async {
    print("analyse image by gemini");
    if (model == null) {
      print("gemini modell ist nicht initialisiert");
      return "Model is not initialized.";
    }

    // Lese das Bild als Bytes ein und kodiert es als Base64
    List<int> imageBytes = await imageFile.readAsBytes();
    String base64Image = base64Encode(imageBytes);

    // Erstelle den Text-Prompt mit dem Base64-codierten Bild
    Content prompt = Content.text(
        "Examine the image (encoded as Base64) and identify the pattern shown. "
        "Possible options are: Cross, question mark, Letter R, Letter C, "
        "Letter V, Letter Z, two dashes, heart. "
        "Just give me back the correct option. Here is the image: data:image/jpeg;base64,$base64Image");

    var response = await model!.generateContent([prompt]);
    print(response.text);
    return response.text;
  }

  Future<String> formatCode(String code) async {
    print("Formatieren des Codes durch Gemini");
    if (model == null) {
      print("Gemini Modell ist nicht initialisiert");
      return "Model is not initialized.";
    }

    // Erstelle den Prompt mit dem Quellcode
    Content prompt = Content.text(
        "Please format the following program code correctly with indentations, line breaks "
        " and other necessary adjustments. Only return the formatted code, "
        "without additional explanations or comments. Do not delete any of the code, just adjust the "
        "indentations and formatting. Keep the code that is outcommented outcommented.  This is the code:\n$code");

    // Anfrage an das Modell senden und die Antwort abrufen
    var response = await model!.generateContent([prompt]);
    print("Formatierter Code: ${response.text}");
    return response.text!;
  }

  Future<String?> explainCodeWithGemini(
      String fullCode, String specificPart) async {
    if (model == null) {
      return "Modell ist nicht initialisiert.";
    }

    // Erstelle den Prompt, der das vollständige Programm und den spezifischen Teil beschreibt
    Content prompt = Content.text(
        "Explain the following program code and specifically focus on the specific part mentioned. Try to answer as short as possible. Give an answer in english and one in german "
        "Entire program code: '$fullCode'. Specific code: '$specificPart'.");

    // Anfrage an das Modell senden und die Antwort abrufen
    var response = await model!.generateContent([prompt]);

    print("Erklärung des Codes: ${response.text}");
    return response.text;
    }
}
