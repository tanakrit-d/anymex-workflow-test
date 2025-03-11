import 'package:anymex/utils/string_extensions.dart';

import 'package:http_interceptor/http_interceptor.dart';

import '../../models/Offline/Hive/video.dart';
import '../http/m_client.dart';

class SibnetExtractor {
  final InterceptedClient client =
      MClient.init(reqcopyWith: {'useDartHttpClient': true});

  Future<List<Video>> videosFromUrl(String url, {String prefix = ""}) async {
    List<Video> videoList = [];
    try {
      final response = await client.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return [];
      }

      String script = response.body;
      String slug = script
          .substringAfter("player.src")
          .substringAfter("src:")
          .substringAfter("\"")
          .substringBefore("\"");

      String videoUrl =
          slug.contains("http") ? slug : "https://${Uri.parse(url).host}$slug";

      Map<String, String> videoHeaders = {
        "Referer": url,
      };

      videoList.add(
        Video(videoUrl, "$prefix - Sibnet", videoUrl, headers: videoHeaders),
      );

      return videoList;
    } catch (_) {
      return [];
    }
  }
}
