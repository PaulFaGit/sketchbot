import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class FileDrawer extends StatefulWidget {
  final Function(String) onFileSelected;
  final Function(List<String>) onFileListUpdated;

  FileDrawer({required this.onFileSelected, required this.onFileListUpdated});

  @override
  _FileDrawerState createState() => _FileDrawerState();
}

class _FileDrawerState extends State<FileDrawer> {
  List<String> files = [];
  final String fixedFileName =
      'TTT_Game1.txt'; // Name der Datei
  final String fixedFileContent = '''
```java
public class TicTacToe {
    private char[][] board;
    private char currentPlayer;

    public TicTacToe() {
        board = new char[3][3];
        currentPlayer = 'X';
        clearBoard();
    }

              public void clearBoard() {
                  for (int i = 0; i < 3; i++) {
                      for (int j = 0; j < 3; j++) {
                          board[i][j] = '-';
                      }
                  }
              }

          public void showBoard() {
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) {
                System.out.print(board[i][j] + " ");
            }
            System.out.println();}
    }

  public boolean isBoardFull() {
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) {
                if (board[i][j] == '-') {
                    return false;
                }
            }
        }
        return true;
    }

       public boolean makeMove(int row, int col) {


        if (row >= 0 && row < 3 && col >= 0 && col < 3 && board[row][col] == '-') {
            board[row][col] = currentPlayer;
            return true;
        }
        return false;
    }

    public boolean checkWin() {
        return (checkRows() || checkColumns() || checkDiagonals());
    }

    private boolean checkRows() {
        for (int i = 0; i < 3; i++) {
            if (board[i][0] == currentPlayer && board[i][1] == currentPlayer && board[i][2] == currentPlayer) {
                return true;
            }
        }
        return false;
    }

    private boolean checkColumns() {
        for (int i = 0; i < 3; i++) {
            if (board[0][i] == currentPlayer && board[1][i] == currentPlayer && board[2][i] == currentPlayer) {
                return true;
            }
        }
        return false;
    }

    private boolean checkDiagonals() {
        if (board[0][0] == currentPlayer && board[1][1] == currentPlayer && board[2][2] == currentPlayer) {
            return true;
        }
        if (board[0][2] == currentPlayer && board[1][1] == currentPlayer && board[2][0] == currentPlayer) {
            return true;
        }
        return false;
    }

    public static void main(String[] args) {
        TicTacToe game = new TicTacToe();
        while (true) {
            game.showBoard();
            int row = 0; // Simulated input
            int col = 0; // Simulated input
            if (game.makeMove(row, col)) {
                if (game.checkWin()) {
                    game.showBoard();
                    System.out.println("Player " + game.currentPlayer + " has won!");
                    break;
                } else if (game.isBoardFull()) {
                    game.showBoard();
                    System.out.println("The game is a tie!");
                    break;
                }
                game.currentPlayer = (game.currentPlayer == 'X') ? 'O' : 'X';
            }
        }
    }

    public void showGameRules() {
        System.out.println("Game rules are being shown...");
    }

    public void showAdvancedStatistics() {
        System.out.println("Advanced statistics...");
    }
}
```

'''; // Der Text, der in die Datei geschrieben werden soll
  final String fixedFileName2 = 'TTT_Spiel.txt'; // Name der zweiten Datei
  final String fixedFileContent2 = '''
```java
public class TicTacToe {
    private char[][] spielfeld;
    private char aktuellerSpieler;

    public TicTacToe() {
        spielfeld = new char[3][3];
        aktuellerSpieler = 'X';
        spielfeldLeeren();
    }

          public void spielfeldLeeren() {
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) {
                spielfeld[i][j] = '-';
            }
        }
    }

            public void spielfeldAnzeigen() {
                for (int i = 0; i < 3; i++) {
                    for (int j = 0; j < 3; j++) {
                        System.out.print(spielfeld[i][j] + " ");
                    }
                    System.out.println();
                }
            }

public boolean istSpielfeldVoll() {
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) {
                if (spielfeld[i][j] == '-') {
                    return false;
                }
            }
        }
        return true;
    }

    public boolean zugMachen(int reihe, int spalte) {
        if (reihe >= 0 && reihe < 3 && spalte >= 0 && spalte < 3 && spielfeld[reihe][spalte] == '-') {
            spielfeld[reihe][spalte] = aktuellerSpieler;
            return true;
        }
        return false;
    }

    public boolean siegPruefen() {
        return (reihenPruefen() || spaltenPruefen() || diagonalenPruefen());
    }

    private boolean reihenPruefen() {
        for (int i = 0; i < 3; i++) {
            if (spielfeld[i][0] == aktuellerSpieler && spielfeld[i][1] == aktuellerSpieler && spielfeld[i][2] == aktuellerSpieler) {
                return true;
            }
        }
        return false;
    }

    private boolean spaltenPruefen() {
        for (int i = 0; i < 3; i++) {
            if (spielfeld[0][i] == aktuellerSpieler && spielfeld[1][i] == aktuellerSpieler && spielfeld[2][i] == aktuellerSpieler) {
                return true;
            }
        }
        return false;
    }

    private boolean diagonalenPruefen() {
        if (spielfeld[0][0] == aktuellerSpieler && spielfeld[1][1] == aktuellerSpieler && spielfeld[2][2] == aktuellerSpieler) {
            return true;
        }
        if (spielfeld[0][2] == aktuellerSpieler && spielfeld[1][1] == aktuellerSpieler && spielfeld[2][0] == aktuellerSpieler) {
            return true;
        }
        return false;
    }

    public static void main(String[] args) {
        TicTacToe spiel = new TicTacToe();
        while (true) {
            spiel.spielfeldAnzeigen();
            int reihe = 0; // Simulierter Eingabewert
            int spalte = 0; // Simulierter Eingabewert
            if (spiel.zugMachen(reihe, spalte)) {
                if (spiel.siegPruefen()) {
                    spiel.spielfeldAnzeigen();
                    System.out.println("Spieler " + spiel.aktuellerSpieler + " hat gewonnen!");
                    break;
                } else if (spiel.istSpielfeldVoll()) {
                    spiel.spielfeldAnzeigen();
                    System.out.println("Das Spiel endet unentschieden!");
                    break;
                }
                spiel.aktuellerSpieler = (spiel.aktuellerSpieler == 'X') ? 'O' : 'X';
            }
        }
    }

    public void spielRegelnAnzeigen() {
        System.out.println("Die Spielregeln werden angezeigt...");
    }

    public void erweiterteStatistikenAnzeigen() {
        System.out.println("Erweiterte Statistiken...");
    }
}
```
''';
  @override
  void initState() {
    super.initState();
    _initFiles();
  }

  Future<void> _initFiles() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String fixedFilePath = '${dir.path}/$fixedFileName';
    final String fixedFilePath2 = '${dir.path}/$fixedFileName2';

    // Erstelle eine neue Datei mit dem gespeicherten Textinhalt bei jedem Neustart
    final newFile = File(fixedFilePath);
    await newFile.writeAsString(fixedFileContent);
    // Erstellt die zweite Datei
    final newFile2 = File(fixedFilePath2);
    await newFile2.writeAsString(fixedFileContent2);
    _listFiles();
  }

  Future<void> _listFiles() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final List<FileSystemEntity> entries = dir.listSync();

    setState(() {
      files = entries
          .where((entry) => entry is File && entry.path.endsWith('.txt'))
          .map((entry) => entry.path)
          .toList();
    });
    widget.onFileListUpdated(files);
  }

  Future<void> _createNewFile(String fileName) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String filePath = '${dir.path}/$fileName.txt';
    final File newFile = File(filePath);

    if (await newFile.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("A file with this name already exists."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Erstelle eine neue leere Datei
    await newFile.writeAsString('');

    setState(() {
      files.add(newFile.path);
    });
    widget.onFileListUpdated(files);
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      await file.delete();
      _listFiles(); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting the file: $e"),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildFileItem(String path, int index) {
    return ListTile(
      title: Row(
        children: [
          Text('${index + 1}. ',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 30)), 
          Expanded(
            child: Text(
              path.split('/').last,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteConfirmationDialog(path),
          ),
        ],
      ),
      onTap: () {
        widget.onFileSelected(path);
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog(String path) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete file'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete this file?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteFile(path);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          AppBar(
            title: const Text('File manager'),
            automaticallyImplyLeading: false, // Verhindert das Zurück-Icon
          ),
          ListTile(
            leading: const Icon(Icons.create),
            title: const Text('New file'),
            onTap: _showCreateFileDialog,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) =>
                  _buildFileItem(files[index], index),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateFileDialog() async {
    TextEditingController fileNameController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create new file'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Name your file:'),
                TextField(
                  controller: fileNameController,
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () {
                if (fileNameController.text.isEmpty ||
                    files.contains('${fileNameController.text}.txt')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Give a unique name"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  _createNewFile(fileNameController.text);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}
