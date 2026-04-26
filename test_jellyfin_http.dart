import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const baseUrl = 'https://jellyfin.shark.assistant.nom.br';
  const userId = '8026dbdf93a44d8b9eeb2db5b6faccce';
  const token = 'bd6fce4d436a439ab825e6c7c00e62ea';

  print('Querying Featured Items...');
  const url = '$baseUrl/Items?Recursive=true&Limit=3&IncludeItemTypes=Movie,Series&SortBy=CommunityRating,DateCreated&SortOrder=Descending&Fields=Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,Genres,MediaSources,ImageTags';
  
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {'X-MediaBrowser-Token': token, 'Accept-Language': 'pt-BR'},
    );
    
    if (response.statusCode == 200) {
      final items = jsonDecode(response.body)['Items'] as List;
      for (var item in items) {
        print('---');
        print('ID: ${item['Id']}');
        print('Name: ${item['Name']}');
        print('ImageTags: ${item['ImageTags']}');
        if (item['ImageTags'] != null && item['ImageTags']['Primary'] != null) {
            String tag = item['ImageTags']['Primary'].toString();
            String imgUrl = '$baseUrl/Items/${item['Id']}/Images/Primary?tag=$tag&api_key=$token';
            print('Generated URL: $imgUrl');
        }
      }
    } else {
      print('Error: ${response.statusCode}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
