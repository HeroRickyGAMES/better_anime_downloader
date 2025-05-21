import 'dart:async';
import 'package:puppeteer/puppeteer.dart';

Future<void> delay(int ms) => Future.delayed(Duration(milliseconds: ms));

Future<Map<String, String>> capturarM3u8(String urlInicial) async {
  var browser = await puppeteer.launch(headless: false);
  var page = await browser.newPage();

  String currentUrl = urlInicial;
  String? m3u8Url;

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

      if (newUrl == 'https://betteranime.net/') {
        print('⚠️ Redirecionado para a home! Voltando para a página anterior...');
        try {
          await page.goto(currentUrl, wait: Until.networkIdle);
          print('🔙 Voltou para: $currentUrl');
        } catch (e) {
          print('Erro ao voltar para a URL anterior: $e');
        }
      } else {
        currentUrl = newUrl;
      }
    }
  });

  page.onResponse.listen((response) {
    final respUrl = response.url;
    if (respUrl.endsWith('.m3u8')) {
      m3u8Url = respUrl;
      print('🎯 M3U8 encontrado: $m3u8Url');
    }
  });

  print('➡️ Abrindo URL inicial: $urlInicial');
  await page.goto(urlInicial, wait: Until.networkIdle);

  for (var i = 0; i < 5; i++) {
    await delay(10000);
    if (m3u8Url != null) break;
  }

  await browser.close();

  if (m3u8Url != null) {
    print('✅ Link final .m3u8: $m3u8Url');
    return {'m3u8Url': m3u8Url!, 'currentUrl': currentUrl};
  } else {
    throw Exception('❌ Arquivo .m3u8 não encontrado');
  }
}