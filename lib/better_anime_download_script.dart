import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;

class BetterAnimeDownloader {
  final String token;
  var context;

  BetterAnimeDownloader(this.token, this.context);

  Future<Map<String, dynamic>> findByUrl(String url, {String quality = '1080p'}) async {
    final headers = {
      "cookie": "betteranime_session=$token",
      "Referer": url
    };

    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Website down or invalid URL');
    }

    final document = parser.parse(response.body);
    final name = document.querySelector('.anime-title a')?.innerHtml?.trim();
    final episode = document.querySelector('.anime-title h3')?.innerHtml?.trim();
    final views = document.querySelector('.views')?.innerHtml?.replaceAll(RegExp(r'\D'), '');

    final qualityRegex = RegExp(r'qualityString\["$quality"\]\s*=\s*"([^"]+)"');
    final tokenRegex = RegExp(r'_token:"([^"]+)"');

    String? playerUrl;
    if (quality != '1080p') {
      String? playerInfo;
      String? playerToken;

      document.querySelectorAll('script').forEach((element) {
        final foundToken = tokenRegex.firstMatch(element.innerHtml);
        final foundQuality = qualityRegex.firstMatch(element.innerHtml);
        if (foundToken != null && foundQuality != null) {
          playerInfo = foundQuality.group(1);
          playerToken = foundToken.group(1);
        }
      });

      if (playerInfo == null || playerToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Não foi encontrado nenhuma informação de player ou qualidade!")));
        throw Exception("No player token or info found for quality $quality");
      }

      final changePlayerResponse = await http.post(
        Uri.parse("https://betteranime.net/changePlayer"),
        headers: {
          ...headers,
          "content-type": "application/x-www-form-urlencoded; charset=UTF-8"
        },
        body: "_token=$playerToken&info=$playerInfo",
      );

      if (changePlayerResponse.statusCode != 200) {
        throw Exception('Error while changing player quality');
      }

      playerUrl = jsonDecode(changePlayerResponse.body)['frameLink'];
    } else {
      playerUrl = document.querySelector('iframe')?.attributes['src'];
    }

    if (name == null || episode == null || views == null || playerUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("A URL precisa ser do site BetterAnime!")));
      throw Exception('The anime URL must be from BetterAnime');
    }

    final playerResponse = await http.get(Uri.parse(playerUrl), headers: headers);
    final playerDocument = parser.parse(playerResponse.body);

    final cdnUrls = <String>[];
    playerDocument.querySelectorAll('script').forEach((element) {
      final match = RegExp(r'https?:\/\/\S+\.m3u8').allMatches(element.innerHtml);
      for (var m in match) {
        cdnUrls.add(m.group(0)!);
      }
    });

    if (cdnUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("O CDN URs não foi encontrado!")));
      throw Exception('No CDN URLs found');
    }

    return {
      'name': name,
      'episode': episode,
      'views': views,
      'quality': quality,
      'url': url,
      'cdnUrls': cdnUrls
    };
  }

  Future<void> download(String link, String outputFolder, String fileName) async {
    final outputDir = Directory(outputFolder);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final outputPath = "${outputDir.path}/$fileName.mp4";

    final process = await Process.start(
      'ffmpeg',
      ['-i', link, '-c', 'copy', outputPath],
      runInShell: true,
    );

    process.stdout.transform(utf8.decoder).listen((data) {
      print(data);
    });

    process.stderr.transform(utf8.decoder).listen((data) {
      print("Error: $data");
    });

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception('Error during download');
    }

    print('Download completed: $outputPath');
  }
}
