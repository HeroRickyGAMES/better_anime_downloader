import 'dart:async';
import 'package:puppeteer/puppeteer.dart';
import 'package:http/http.dart' as http; // Para fazer requisições HTTP
import 'dart:convert'; // Para utf8.decode

Future<void> delay(int ms) => Future.delayed(Duration(milliseconds: ms));

// Função auxiliar para resolver URLs relativas
Uri _resolveUri(Uri baseUrl, String relativeUrl) {
  if (Uri.tryParse(relativeUrl)?.isAbsolute ?? false) {
    return Uri.parse(relativeUrl);
  }
  return baseUrl.resolve(relativeUrl);
}

Future<Map<String, String>> capturarM3u8(String urlInicial) async {
  var browser = await puppeteer.launch(headless: false);
  var page = await browser.newPage();

  String currentUrl = urlInicial;
  String? m3u8Url; // Irá armazenar a URL do M3U8 detectada

  final adBlockList = [
    'doubleclick.net',
    'googlesyndication.com',
    'adservice.google.com',
    'ads.pubmatic.com',
    'pagead2.googlesyndication.com',
  ];

  await page.setRequestInterception(true);
  page.onRequest.listen((request) {
    if (adBlockList.any((ad) => request.url.contains(ad))) {
      request.abort();
    } else {
      request.continueRequest();
    }
  });

  page.onFrameNavigated.listen((frame) async {
    if (frame == page.mainFrame) {
      final newUrl = frame.url;
      print('🔄 URL mudou para: $newUrl');
      if (newUrl == 'https://betteranime.net/' && currentUrl != newUrl) {
        print('⚠️ Redirecionado para a home! Tentando voltar para: $currentUrl');
        try {
          await page.goto(currentUrl, wait: Until.networkIdle);
          print('🔙 Voltou para: $currentUrl');
        } catch (e) {
          print('❌ Erro ao voltar para ($currentUrl): $e');
        }
      } else {
        currentUrl = newUrl;
      }
    }
  });

  page.onResponse.listen((response) {
    final respUrl = response.url;
    if (respUrl.contains('.m3u8')) { // Usar 'contains' pode ser mais flexível que 'endsWith'
      m3u8Url = respUrl;
      print('🎯 M3U8 detectado/atualizado para: $m3u8Url');
    }
  });

  print('➡️ Abrindo URL inicial: $urlInicial');
  await page.goto(urlInicial, wait: Until.networkIdle);
  print('✅ Página carregada: ${page.url}');

  // --- CÓDIGO PARA SELECIONAR 1080p ---
  try {
    print('🔎 Procurando pelo botão 1080p...');
    final String xpath1080p =
        "//*[(self::button or self::div or self::a or self::span) and normalize-space(.)='1080p']";
    await page.waitForXPath(xpath1080p, timeout: Duration(seconds: 15));
    List<ElementHandle> elements = await page.$x(xpath1080p);

    if (elements.isNotEmpty) {
      await elements.first.click();
      print('🖱️ Botão 1080p clicado.');
      print('🗑️ Limpando URL M3U8 anterior (se houver).');
      m3u8Url = null; // Limpa para pegar o M3U8 específico do 1080p

      print('⏳ Aguardando um tempo para o(s) M3U8(s) da qualidade 1080p serem carregados...');
      // Espera um tempo fixo para permitir que o navegador solicite todos os M3U8s necessários
      // (master, depois media). O onResponse irá atualizar m3u8Url para o último.
      await delay(15000); // Espera 15 segundos. Ajuste se necessário.
      print('⌛ Tempo de espera inicial para M3U8s concluído.');

    } else {
      print('⚠️ Botão 1080p não encontrado.');
      // Se o botão não for encontrado, ainda esperamos um pouco por qualquer M3U8 que possa carregar.
      print('⏳ Aguardando por M3U8s (botão 1080p não encontrado)...');
      await delay(10000);
    }
  } catch (e) {
    print('❌ Erro ao tentar selecionar 1080p: $e');
    // Mesmo com erro, esperamos um pouco por M3U8s.
    print('⏳ Aguardando por M3U8s (após erro na seleção de 1080p)...');
    await delay(10000);
  }
  // --- FIM DO CÓDIGO PARA SELECIONAR 1080p ---

  String? finalPlayableM3u8Url = m3u8Url;

  if (m3u8Url == null) {
    print('⚠️ Nenhum M3U8 foi detectado após o período de espera principal.');
  } else {
    print('ℹ️ M3U8 final detectado pelo Puppeteer (antes do parsing): $m3u8Url');
    try {
      print('🔎 Verificando se o M3U8 capturado ($m3u8Url) é um Master Playlist...');
      var response = await http.get(Uri.parse(m3u8Url!)); // Usar m3u8Url! pois verificamos se é null
      if (response.statusCode == 200) {
        String m3u8Content = utf8.decode(response.bodyBytes);

        if (m3u8Content.contains('#EXT-X-STREAM-INF')) {
          print('✅ É um Master Playlist. Procurando pelo Media Playlist 1080p...');
          final lines = m3u8Content.split('\n');
          String? mediaPlaylistRelativeUrl;
          int bestBandwidthFor1080p = 0; // Para o caso de múltiplas opções 1080p

          for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.startsWith('#EXT-X-STREAM-INF')) {
              bool is1080pStream = line.contains('RESOLUTION=1920x1080');

              if (is1080pStream && (i + 1 < lines.length)) {
                String nextLine = lines[i+1].trim();
                if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
                  // Se houver múltiplas streams 1080p, podemos pegar a de maior BANDWIDTH
                  RegExp bandwidthRegex = RegExp(r'BANDWIDTH=(\d+)');
                  Match? bandwidthMatch = bandwidthRegex.firstMatch(line);
                  int currentBandwidth = bandwidthMatch != null ? int.parse(bandwidthMatch.group(1)!) : 0;

                  if (currentBandwidth > bestBandwidthFor1080p) {
                    bestBandwidthFor1080p = currentBandwidth;
                    mediaPlaylistRelativeUrl = nextLine;
                    print('🎞️ Encontrado Media Playlist 1080p (relativo) com BANDWIDTH $currentBandwidth: $mediaPlaylistRelativeUrl');
                  }
                }
              }
            }
          }

          // Se não encontrou 1080p explícito, mas há apenas um stream, pega ele
          if (mediaPlaylistRelativeUrl == null && lines.where((l) => l.startsWith('#EXT-X-STREAM-INF')).length == 1) {
            for (var i = 0; i < lines.length; i++) {
              var line = lines[i].trim();
              if (line.startsWith('#EXT-X-STREAM-INF') && (i + 1 < lines.length)) {
                String nextLine = lines[i+1].trim();
                if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
                  mediaPlaylistRelativeUrl = nextLine;
                  print('⚠️ Não encontrou 1080p explícito, mas há apenas um stream. Pegando (relativo): $mediaPlaylistRelativeUrl');
                  break;
                }
              }
            }
          }


          if (mediaPlaylistRelativeUrl != null) {
            Uri masterPlaylistUri = Uri.parse(m3u8Url!);
            Uri mediaPlaylistAbsoluteUri = _resolveUri(masterPlaylistUri, mediaPlaylistRelativeUrl);
            finalPlayableM3u8Url = mediaPlaylistAbsoluteUri.toString();
            print('✅ URL absoluto do Media Playlist (selecionado): $finalPlayableM3u8Url');
          } else {
            print('⚠️ Não foi possível encontrar um Media Playlist 1080p ou único dentro do Master Playlist. Usando o Master Playlist original.');
            finalPlayableM3u8Url = m3u8Url; // Mantém o master como fallback
          }
        } else {
          print('ℹ️ O M3U8 detectado não é um Master Playlist (provavelmente já é o Media Playlist desejado: $finalPlayableM3u8Url).');
        }
      } else {
        print('❌ Falha ao baixar conteúdo do M3U8 ($m3u8Url): ${response.statusCode}. Usando este URL como fallback.');
        finalPlayableM3u8Url = m3u8Url;
      }
    } catch (e) {
      print('❌ Erro ao processar o M3U8 ($m3u8Url): $e. Usando este URL como fallback.');
      finalPlayableM3u8Url = m3u8Url;
    }
  }

  await browser.close();

  if (finalPlayableM3u8Url != null) {
    print('✅ Link final .m3u8 para reprodução: $finalPlayableM3u8Url');
    return {'m3u8Url': finalPlayableM3u8Url, 'currentUrl': currentUrl, 'm3u8FinalURL': finalPlayableM3u8Url};
  } else {
    print('❌ Arquivo .m3u8 não encontrado após todas as tentativas.');
    throw Exception('❌ Arquivo .m3u8 não encontrado');
  }
}