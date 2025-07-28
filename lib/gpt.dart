import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:Sketchbot/chatBot_widget.dart';

class GPT {
  final String apiKey = 'PASTE-KEY-HERE';

  GPT();

  Future<String> sendImageAndGetResponse(File imageFile) async {
    // Encode the image file to base64
    String base64Image = base64Encode(await imageFile.readAsBytes());
    print(base64Image);
    // Set up headers
    Map<String, String> headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $apiKey"
    };

// Set up the payload
    Map<String, dynamic> payload = {
      "model": "gpt-4-turbo",
      "messages": [
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text":
                  "Look at the picture carefully. In the picture, you see a text editor in the middle and a file list on the left. Your task is to interpret the blue drawing in the picture and assign it to one of these possibilities. You have the following options: 1. Cross, 2. Question mark, 3. Letter R, 4. Letter C, 5. Letter V, 6. Letter Z, 7. Two lines, 8. Heart, 9. Arrow. If it is an arrow, enter the number the arrow points to and format your answer exactly like this: 'Arrow + number'. Example: 'Arrow + 2'. Any other output such as 'Arrow2' or 'Arrow-2' is incorrect and will be rejected. In each case, just give me the word back without any further explanation. Important: An arrow always has a pointed tip and should not be confused with the letters C or V, which do not have a pointed tip.Two lines, on the other hand, always consist of two separate, parallel lines without a point. Make sure that these two lines are never confused with an arrow. If they are two lines that are not connecting you give me always two lines. The letter V is shaped like two straight lines meeting at a point to form an open angle, but it does not have an extended tip that suggests direction. It has a symmetrical, balanced appearance and no sharp, projecting point."
            },
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/jpeg;base64,$base64Image",
                "detail": "low"
              }
            }
          ]
        }
      ],
      "max_tokens": 300
    };

// Send the POST request
    http.Response response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      print(response.body);
      // Parse the response
      var jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      return jsonResponse['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to load data: ${response.body}');
    }
  }

  Future<String> explainCode(String fullCode, String specificPart) async {
    // Setze die Header
    Map<String, String> headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $apiKey"
    };

    // Erstelle den Payload
    Map<String, dynamic> payload = {
      "model": "gpt-4-turbo",
      "messages": [
        {
          "role": "user",
          "content":
              "Explain to me what the following program code does and in particular what the specific part of the code does. Entire program code: '$fullCode'. Specific code: '$specificPart'"
        }
      ],
      "max_tokens": 200 // Begrenze die Antwort auf 200 Tokens
    };

    // Sende die POST-Anfrage
    http.Response response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      // Parse die Antwort
      print(response.body);
      var jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      return jsonResponse['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to load data: ${response.body}');
    }
  }

  Future<String> getDetailedResponse(List<ChatMessage> messages,
      String fullText, String selectedText, String message) async {
    // Setze die Header
    print("Start der API Anfrage");
    Map<String, String> headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $apiKey"
    };

    // Erstelle die Nachrichtliste für den Payload
    List<Map<String, String>> formattedMessages = messages.map((msg) {
      return {"role": msg.isUser ? "user" : "assistant", "content": msg.text};
    }).toList();

    // Füge die neuen Nachrichten hinzu
    formattedMessages.add({"role": "user", "content": message});
    formattedMessages.add(
        {"role": "user", "content": "Here is the complete code: $fullText"});
    if (!selectedText.isEmpty)
      formattedMessages.add({
        "role": "user",
        "content": "Here is the selected code: $selectedText"
      });
    formattedMessages.add({
      "role": "system",
      "content":
          "You are a virtual assistant who helps developers in an IDE. You have two tasks and should only fulfill one of the two tasks for each message. You should recognize from the user's message which of the tasks you should perform. \n First task: You answer the user's questions about the source code in human language. For this task, the format should be as follows: Explanation: (here is the explanation) \n Second task: You carry out the desired code change of the user. You only give the entire source code without additional explanations. For this task, your answer should have the following format \n Full code: \n (Here the complete source code of the entire file). You should always specify the entire source code here, including the code that you have not changed"
    });

    // Erstelle den Payload
    Map<String, dynamic> payload = {
      "model": "gpt-4-turbo",
      "messages": formattedMessages,
      "max_tokens": 3000 // Begrenze die Antwort auf 300 Tokens
    };

    // Sende die POST-Anfrage
    http.Response response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      // Parse die Antwort
      print(response.body);
      var jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      print("ende der api anfrage");
      return jsonResponse['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to load data: ${response.body}');
    }
  }

  Future<String> formatCode(String code) async {
    // Setze die Header
    Map<String, String> headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $apiKey"
    };

    // Erstelle den Payload
    Map<String, dynamic> payload = {
      "model": "gpt-4-turbo",
      "messages": [
        {
          "role": "user",
          "content":
              "Please format the following program code correctly with indentations, line breaks and other necessary adjustments. Return only the formatted code, without any additional explanations or comments. Return the entire code, without any explanations. Do not delete any of the code, just adjust the indentations etc. This is the code you should format:\n '$code'"
        }
      ],
      "max_tokens": 3000 // Begrenze die Antwort auf 300 Tokens
    };

    // Sende die POST-Anfrage
    http.Response response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      // Parse die Antwort
      print(response.body);
      var jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      return jsonResponse['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to load data: ${response.body}');
    }
  }
}
