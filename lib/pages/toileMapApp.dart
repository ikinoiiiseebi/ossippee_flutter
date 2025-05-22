import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../components/ToiletDetailPanel.dart';
import '../components/ToiletFilterDialog.dart';
import '../components/ToiletListView.dart';
import '../components/ToiletRegisterForm.dart';
import '../components/ToiletReviewDialog.dart';

class ToiletMapApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'トイレマップ口コミサイト',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: ToiletMapHomePage(),
    );
  }
}

class ToiletMapHomePage extends StatefulWidget {
  @override
  State<ToiletMapHomePage> createState() => _ToiletMapHomePageState();
}

class _ToiletMapHomePageState extends State<ToiletMapHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 仮データ
  int selectedToiletIndex = -1;
  List<Map<String, dynamic>> toiletList = [
    {
      'name': '駅前トイレ',
      'lat': 35.68,
      'lng': 139.76,
      'distance': 120,
      'rating': 4.0,
      'features': ['ウォシュレット', '洋式', '多目的'],
      'address': '東京都千代田区丸の内1-1-1',
      'cleanliness': 4,
      'comments': [
        {'user': 'Taro', 'rating': 4, 'comment': 'きれいでした'},
      ],
      'images': []
    },
    {
      'name': '公園トイレ',
      'lat': 35.684,
      'lng': 139.758,
      'distance': 350,
      'rating': 3.0,
      'features': ['和式'],
      'address': '東京都千代田区丸の内2-2-2',
      'cleanliness': 3,
      'comments': [
        {'user': 'Hanako', 'rating': 3, 'comment': 'まあまあです'},
      ],
      'images': []
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
  }

  void _onSelectToilet(int index) {
    setState(() {
      selectedToiletIndex = index;
      _tabController.animateTo(2);
    });
  }

  void _onShowRegisterForm() {
    _tabController.animateTo(1);
  }

  void _onShowList() {
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            // サイドパネルエリア
            width: 420,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black12)],
            ),
            child: Column(
              children: [
                // 上部操作バー
                Container(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.search),
                          label: Text('近くのトイレ検索'),
                          onPressed: _onShowList,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.add),
                          label: Text('＋トイレを登録'),
                          onPressed: _onShowRegisterForm,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.filter_list),
                        tooltip: 'フィルター',
                        onPressed: () {
                          // フィルターUI表示
                          showDialog(
                            context: context,
                            builder: (_) => ToiletFilterDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // タブ表示部
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: "検索結果"),
                    Tab(text: "トイレ登録"),
                    Tab(text: "詳細情報"),
                  ],
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // ①検索結果リスト
                      ToiletListView(
                        toiletList: toiletList,
                        onSelect: _onSelectToilet,
                      ),
                      // ②トイレ登録フォーム
                      ToiletRegisterForm(
                        onRegister: (data) {
                          setState(() {
                            toiletList.add(data);
                            _tabController.animateTo(0);
                          });
                        },
                      ),
                      // ③詳細情報パネル
                      selectedToiletIndex == -1
                          ? Center(child: Text("トイレを選択してください"))
                          : ToiletDetailPanel(
                              toilet: toiletList[selectedToiletIndex],
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 地図エリア
          Expanded(
            flex: 7,
            child: Stack(
              children: [
                // 地図
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(35.68, 139.76),
                    zoom: 15,
                  ),
                  markers: toiletList
                      .asMap()
                      .entries
                      .map((entry) => Marker(
                            markerId: MarkerId('${entry.key}'),
                            position:
                                LatLng(entry.value['lat'], entry.value['lng']),
                            infoWindow: InfoWindow(
                              title: entry.value['name'],
                              snippet: '清潔度: ${entry.value['cleanliness']}',
                              onTap: () => _onSelectToilet(entry.key),
                            ),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                                entry.value['cleanliness'] >= 4
                                    ? BitmapDescriptor.hueBlue
                                    : BitmapDescriptor.hueRed),
                          ))
                      .toSet(),
                  myLocationEnabled: true,
                  zoomControlsEnabled: true,
                ),
                // 地図上の現在地ボタン
                Positioned(
                  top: 24,
                  right: 24,
                  child: FloatingActionButton(
                    heroTag: 'currentLocation',
                    child: Icon(Icons.my_location),
                    onPressed: () {
                      // 現在地に戻るロジック
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------- 各サブウィジェット -------------
