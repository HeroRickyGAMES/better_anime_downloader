import 'dart:io';
import 'package:better_anime_downloader_flutter/capturarM3u8.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

// Desenvolvido por HeroRickyGames com a ajuda de Deus para ver anime!

String url = "";

Future<void> convertToMp4(String inputUrl, String filename, var context) async {
  print(inputUrl);
  String? directoryPath = await FilePicker.platform.getDirectoryPath();
  if (directoryPath != null) {
    var filem3 = File('$directoryPath/$filename.m3u8');
    var file = File('$directoryPath/$filename.mp4');
    var map = await capturarM3u8(url);

    //Fazer download em get mesmo!
    final uri = Uri.parse(url);
    final response = await http.get(Uri.parse(map['m3u8Url']!));

    if (response.statusCode == 200) {
      final file = File(filem3.path);
      filem3 = await file.writeAsBytes(response.bodyBytes);
      print('Arquivo salvo em: ${filem3.path}');
    } else {
      print('Falha ao baixar arquivo. Status code: ${response.statusCode}');
    }

    String command = 'vlc/vlc "${filem3.path}" --sout "#transcode{vcodec=h264,acodec=mp3,ab=128,channels=2,samplerate=44100}:file{dst=${file.path}}" vlc://quit';

    ProcessResult result = await Process.run('powershell.exe', ['-c', command]);

    print(result.stdout.toString());
    await filem3.delete();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pronto!')));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Nenhum diretório escolhido")));
  }
}

void main() {
  runApp(
    MaterialApp(
      home: homeApp(),
      theme: ThemeData(
        brightness: Brightness.dark,
      ),
    ),
  );
}

class homeApp extends StatefulWidget {
  const homeApp({super.key});

  @override
  State<homeApp> createState() => _homeAppState();
}

class _homeAppState extends State<homeApp> {
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('Better Anime Downloader'),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: Container(
        padding: EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/betterAnime.png"),
            Container(
              padding: EdgeInsets.all(16),
              child: TextField(
                cursorColor: Colors.black,
                keyboardType: TextInputType.url,
                enableSuggestions: true,
                autocorrect: true,
                onChanged: (value) {
                  url = value;
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(width: 3, color: Colors.black),
                  ),
                  labelText: 'URL',
                ),
              ),
            ),
            ElevatedButton(
                onPressed: () async {
                  if (url.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('A URL está vazia!')));
                    return;
                  }

                  final regex = RegExp(r'/anime/[^/]+/([^/]+)/episodio-(\d+)', caseSensitive: false);

                  final match = regex.firstMatch(url);

                  if (match != null) {
                    final nomeAnime = match.group(1)!;
                    final episodio = match.group(2)!;

                    print('Anime: $nomeAnime');
                    print('Episódio: $episodio');

                    // Criando nome de arquivo
                    final fileName = '$nomeAnime-episodio-$episodio'.replaceAll(":", ' ').replaceAll(',', ' ').replaceAll("-", ' ');
                    convertToMp4(url, fileName, context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('URL inválida')));
                    print('URL inválida.');
                    return;
                  }
                  //await convertToMp4(url, 'epdoanime', context);
                },
                child: Text('Baixar'))
          ],
        ),
      ),
    );
  }
}
