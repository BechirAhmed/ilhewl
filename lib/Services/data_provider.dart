import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/Services/song_provider.dart';

class DataProvider with ChangeNotifier {
  SongProvider _songProvider;

  DataProvider({
    @required SongProvider songProvider,
  })  : _songProvider = songProvider;

  Future<void> init(BuildContext context) async {
    final Map data = await Api().fetchHomePageData();

    await _songProvider.init(data['songs']);

  }
}
