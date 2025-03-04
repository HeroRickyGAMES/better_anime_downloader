import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:better_anime_downloader_flutter/better_anime_download_script.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

//Desenvolvido por HeroRickyGames com a ajuda de Deus para ver anime!

String url = "";

downloadM3U8File(String url, String filePath, var context) async {
  print(url);
  final headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36',
    'Referer': 'https://play.betteranime.net/', // Substitua com o valor correto se necessário
    // Adicione outros cabeçalhos se necessário
  };

  // Faça o download do arquivo M3U8
  final response = await http.get(Uri.parse(url), headers: headers);

  print(response.statusCode);
  if (response.statusCode == 200) {
    // Crie o arquivo no sistema de arquivos local
    final file = File(filePath);
    var bodybytes = await file.writeAsBytes(response.bodyBytes);
    print("Arquivo M3U8 baixado com sucesso!");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Arquivo M3U8 baixado com sucesso! O primeiro passo foi concluido! Agora a conversão irá iniciar!")));
    return bodybytes;
  } else {
    throw Exception("Erro ao baixar o arquivo M3U8");
  }
}

Future<void> convertToMp4(String inputUrl, String filename, var context) async {

  print(inputUrl);
  String? directoryPath = await FilePicker.platform.getDirectoryPath();
  if(directoryPath != null){
    final filem3 = File('$directoryPath/$filename.m3u8');
    final file = File('$directoryPath/$filename.mp4');
    var export = await downloadM3U8File(inputUrl, filem3.path, context);
    print(export);
    String command = 'vlc/vlc "${filem3.path}" --sout "#transcode{vcodec=h264,acodec=mp3,ab=128,channels=2,samplerate=44100}:file{dst=${file.path}" vlc://quit';

    ProcessResult result = await Process.run('powershell.exe', ['-c', command]);

    print(result.stdout.toString());
    filem3.delete();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pronto!')));
  }else{
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Nenhum diretório escolhido")));
  }
}

void main(){
  runApp(
    MaterialApp(
      home: homeApp(),
      theme: ThemeData(
        brightness: Brightness.dark
      ),
    )
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
        backgroundColor: Colors.blue
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
                keyboardType: TextInputType.name,
                enableSuggestions: true,
                autocorrect: true,
                onChanged: (value){
                  url = value;
                },
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                        width: 3,
                        color: Colors.black
                    ),
                  ),
                  labelText: 'URL',
                ),
              ),
            ),
            ElevatedButton(
                onPressed: () async {
                  if(url == ""){
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('A url está vazio!')));
                  }else{
                    final downloader = BetterAnimeDownloader("a36ba168-a392-41f1-b360-4d808dbc89a9", context);
                    try {
                      final animeInfo = await downloader.findByUrl(url);
                      String episodio = '${animeInfo['name']} ${animeInfo['episode']}';

                      String input = '${animeInfo['cdnUrls'][0].replaceAll(r'\/', "/")}"}}';

                      // Extraindo a URL da imagem (antes do primeiro ponto e vírgula)
                      String imageUrl = input.split('";').first;

                      // Usando uma expressão regular para pegar a URL do arquivo .m3u8
                      RegExp fileRegex = RegExp(r'"file":"(https?:\/\/\S+\.m3u8)"');
                      Match? fileMatch = fileRegex.firstMatch(input);
                      String? fileUrl = fileMatch?.group(1);

                      // Verificando se ambos os valores não são nulos
                      if (imageUrl.isNotEmpty && fileUrl != null) {
                        // Criando o mapa com os valores extraídos
                        Map<String, dynamic> result = {
                          "image": imageUrl,
                          "sources": {
                            "file": fileUrl
                          }
                        };
                        await convertToMp4(result['sources']['file'], episodio.replaceAll(":", ''), context);

                        print(result['sources']['file']);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao extrair dados!')));
                      }

                      //final folder = "downloads/${animeInfo['name']}"; // Pasta personalizada
                      //final fileName = "Episodio_${animeInfo['episode']}";
                      //
                      //await downloader.download(animeInfo['cdnUrls'][0], folder, fileName);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
                    }
                  }
        
                }, child: Text('Baixar')
            )
          ],
        ),
      ),
    );
  }
}
