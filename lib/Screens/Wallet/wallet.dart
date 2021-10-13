import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/Helpers/countrycodes.dart';
import 'package:ilhewl/CustomWidgets/gradientContainers.dart';
import 'package:ilhewl/Helpers/picker.dart';
import 'package:ilhewl/Screens/Collections/collection.dart' as topScreen;
import 'package:ilhewl/Screens/Home/saavn.dart' as homeScreen;
// import 'package:ext_storage/ext_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ilhewl/Helpers/config.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:package_info/package_info.dart';

class WalletPage extends StatefulWidget {
  final Function callback;
  WalletPage({this.callback});
  @override
  _WalletPageState createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  Box settingsBox = Hive.box('settings');
  String name = Hive.box('settings').get('name', defaultValue: 'Guest User');
  String currency = Hive.box('settings').get('currency') ?? "MRU";

  List dirPaths = Hive.box('settings').get('searchPaths', defaultValue: []);
  String region = Hive.box('settings').get('region', defaultValue: 'Arabic');
  List languages = [
    "Arabic",
    "English",
  ];
  List preferredLanguage = Hive.box('settings')
      .get('preferredLanguage', defaultValue: ['Hindi'])?.toList();


  Map wallet;
  List orders = [];
  bool loading = true;
  @override
  void initState() {
    main();
    super.initState();
  }

  void main() async {
    wallet = await Api().fetchWalletData();
    if(wallet["orders"] != null){
      orders = wallet["orders"];
    }

    loading = false;
    setState(() {});
  }

  updateUserDetails(String key, dynamic value) {
    final userID = Hive.box('settings').get('userID');
    final dbRef = FirebaseDatabase.instance.reference().child("Users");
    dbRef.child(userID.toString()).update({"$key": "$value"});
  }

  Future<void> _pullRefresh() async {
    setState(() {
      loading = true;
    });
    main();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.transparent,
      body: CustomScrollView(physics: BouncingScrollPhysics(), slivers: [
        SliverAppBar(
          elevation: 0,
          stretch: true,
          pinned: true,
          expandedHeight: MediaQuery.of(context).size.height / 4.5,
          flexibleSpace: FlexibleSpaceBar(
            centerTitle: true,
            stretchModes: [StretchMode.zoomBackground],
            background: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.transparent],
                ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
              },
              blendMode: BlendMode.dstIn,
              child: Center(
                child: Text(
                  "Wallet",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 80,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate(
            [
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 5, 15, 0),
                child: ListTile(
                  title: Text(
                    'You Have',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).accentColor,
                    ),
                  ),
                  trailing: loading ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).accentColor,
                      strokeWidth: 2,
                    ),
                  ) : Text(
                    loading ? "0": wallet["balance"]+" $currency",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).accentColor,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                child: Text(
                  'Transactions',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).accentColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(5.0, 0, 5, 10),
                child: GradientCard(
                  child: RefreshIndicator(
                    child: ListView.builder(
                      physics: BouncingScrollPhysics(),
                      shrinkWrap: true,
                      padding: EdgeInsets.fromLTRB(0, 10, 0, 10),
                      scrollDirection: Axis.vertical,
                      itemCount: orders.isEmpty ? 0 : orders.length,
                      itemBuilder: (context, idx) {
                        return ListTile(
                          title: Text("Order #${orders[idx]['transaction_id']}"),
                          subtitle: Text('${orders[idx]['object']['title']}'),
                          trailing: SizedBox(
                            width: 150,
                            child: Text(
                              "${orders[idx]['amount']} ${orders[idx]['currency']}",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                          dense: true,
                        );
                      }
                    ),
                    onRefresh: _pullRefresh,
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        child: loading ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            color: Theme.of(context).cardColor,
            strokeWidth: 2,
          ),
        ) : Icon(Icons.refresh),
        onPressed: (){
          _pullRefresh();
        },
      ),
    );
  }
}
