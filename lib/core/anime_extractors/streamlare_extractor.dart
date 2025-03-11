import 'package:anymex/utils/string_extensions.dart';

import 'package:http_interceptor/http_interceptor.dart';

import '../../models/Offline/Hive/video.dart';
import '../http/m_client.dart';

class StreamlareExtractor {
  final InterceptedClient client =
      MClient.init(reqcopyWith: {'useDartHttpClient': true});

  Future<List<Video>> videosFromUrl(String url,
      {String prefix = "", String suffix = ""}) async {
    try {
      final id = url.split('/').last;
      final playlistResponse = await client.post(
        Uri.parse('https://slwatch.co/api/video/stream/get'),
        headers: {'Content-Type': 'application/json'},
        body: '{"id":"$id"}',
      );

      final playlist = playlistResponse.body;
      final type = playlist.substringAfter('"type":"').substringBefore('"');

      if (type == 'hls') {
        final masterPlaylistUrl = playlist
            .substringAfter('"file":"')
            .substringBefore('"')
            .replaceAll(r'\/', '/');
        final masterPlaylistResponse =
            await client.get(Uri.parse(masterPlaylistUrl));
        final masterPlaylist = masterPlaylistResponse.body;

        const separator = '#EXT-X-STREAM-INF';
        return masterPlaylist
            .substringAfter(separator)
            .split(separator)
            .map((value) {
          final quality =
              '${value.substringAfter('RESOLUTION=').substringAfter('x').substringBefore(',')}p';
          final videoUrl =
              value.substringAfter('\n').substringBefore('\n').let((urlPart) {
            return !urlPart.startsWith('http')
                ? masterPlaylistUrl.substringBefore('master.m3u8') + urlPart
                : urlPart;
          });

          return Video(
              videoUrl, _buildQuality(quality, prefix, suffix), videoUrl);
        }).toList();
      } else {
        const separator = '"label":"';
        List<Video> videoList = [];
        List<String> values =
            playlist.substringAfter(separator).split(separator);
        for (var value in values) {
          final quality = value.substringAfter(separator).substringBefore('",');
          final apiUrl = value
              .substringAfter('"file":"')
              .substringBefore('",')
              .replaceAll('\\', '');
          final response = await client.post(Uri.parse(apiUrl));
          final videoUrl = response.request!.url.toString();

          videoList.add(Video(
              videoUrl, _buildQuality(quality, prefix, suffix), videoUrl));
        }
        return videoList;
      }
    } catch (_) {
      return [];
    }
  }

  String _buildQuality(String resolution,
      [String prefix = '', String suffix = '']) {
    final buffer = StringBuffer();
    if (prefix.isNotEmpty) buffer.write('$prefix ');
    buffer.write('Streamlare:$resolution');
    if (suffix.isNotEmpty) buffer.write(' $suffix');

    return buffer.toString();
  }
}

extension LetExtension<T> on T {
  R let<R>(R Function(T) block) {
    return block(this);
  }
}
