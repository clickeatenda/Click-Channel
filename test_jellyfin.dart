import 'dart:convert';
import 'dart:io';

void main() async {
  final baseUrl = 'https://jellyfin.shark.assistant.nom.br';
  final userId = '8026dbdf93a44d8b9eeb2db5b6faccce';
  final token = 'bd6fce4d436a439ab825e6c7c00e62ea';

  final url = baseUrl + '/Users/' + userId + '/Items/Latest?Limit=2&IncludeItemTypes=Movie,Series&Fields=Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,Genres,MediaSources,ImageTags';
  print('Requesting: ' + url);

  try {
    final request = await HttpClient().getUrl(Uri.parse(url));
    request.headers.add('X-MediaBrowser-Token', token);
    
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 200) {
      print('Success!');
      final items = jsonDecode(responseBody) as List;
      for (var item in items) {
        print('Name: ' + item['Name'].toString());
        print('ImageTags: ' + item['ImageTags'].toString());
      }
    } else {
      print('Error: ' + response.statusCode.toString() + ' - ' + responseBody);
    }
  } catch (e) {
    print('Failed: ' + e.toString());
  }
}
