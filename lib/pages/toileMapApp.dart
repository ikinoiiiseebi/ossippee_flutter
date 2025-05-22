import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../components/ToiletDetailPanel.dart';
import '../components/ToiletFilterDialog.dart';
import '../components/ToiletListView.dart';
import '../components/ToiletRegisterForm.dart';

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

  // Firestore から取得したトイレ情報リスト
  List<Map<String, dynamic>> toiletList = [];
  int selectedToiletIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Firestore コレクション 'toilets' をリアルタイム購読
    FirebaseFirestore.instance
        .collection('toilets')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        toiletList = snapshot.docs.map((doc) {
          final data = doc.data();
          // 安全なパース
          double safeLat =
              (data['lat'] is num) ? (data['lat'] as num).toDouble() : 0.0;
          double safeLng =
              (data['lng'] is num) ? (data['lng'] as num).toDouble() : 0.0;
          int safeDistance =
              (data['distance'] is num) ? (data['distance'] as num).toInt() : 0;
          double safeRating = (data['rating'] is num)
              ? (data['rating'] as num).toDouble()
              : 0.0;
          int safeCleanliness = (data['cleanliness'] is num)
              ? (data['cleanliness'] as num).toInt()
              : 0;

          return {
            'id': doc.id,
            'name': data['name'] as String? ?? '',
            'lat': safeLat,
            'lng': safeLng,
            'distance': safeDistance,
            'rating': safeRating,
            'features': List<String>.from(data['features'] ?? []),
            'address': data['address'] as String? ?? '',
            'cleanliness': safeCleanliness,
            'comments': List<Map<String, dynamic>>.from(data['comments'] ?? []),
            'images': List<String>.from(data['images'] ?? []),
          };
        }).toList();
      });
    });
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // サイドパネル
          Container(
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
                          showDialog(
                            context: context,
                            builder: (_) => ToiletFilterDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // タブ
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
                // タブビュー
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // ① 検索結果リスト
                      ToiletListView(
                        toiletList: toiletList,
                        onSelect: _onSelectToilet,
                      ),
                      // ② トイレ登録フォーム
                      ToiletRegisterForm(),
                      // ③ 詳細パネル
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
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(35.68, 139.76),
                    zoom: 15,
                  ),
                  markers: toiletList.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final t = entry.value;
                    return Marker(
                      markerId: MarkerId(t['id']),
                      position: LatLng(t['lat'], t['lng']),
                      infoWindow: InfoWindow(
                        title: t['name'],
                        snippet: '清潔度: ${t['cleanliness']}',
                        onTap: () => _onSelectToilet(idx),
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        t['cleanliness'] >= 4
                            ? BitmapDescriptor.hueBlue
                            : BitmapDescriptor.hueRed,
                      ),
                    );
                  }).toSet(),
                  myLocationEnabled: true,
                  zoomControlsEnabled: true,
                ),
                // 現在地ボタン
                Positioned(
                  top: 24,
                  right: 24,
                  child: FloatingActionButton(
                    heroTag: 'currentLocation',
                    child: Icon(Icons.my_location),
                    onPressed: () {
                      // 必要に応じて現在地取得ロジックを実装
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
