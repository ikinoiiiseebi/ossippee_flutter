import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // 追加
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
  // マーカー一覧を保持
  List<Marker> _markers = [];
  GoogleMapController? _mapController;
  int selectedToiletIndex = -1;
  Position? _currentPosition; // 追加: 現在位置を保持
  bool _isSidePanelVisible = true; // 追加: サイドパネル表示状態

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _determinePosition(); // 追加: 初期位置情報を取得

    // Firestore コレクション 'toilets' をリアルタイム購読
    FirebaseFirestore.instance
        .collection('toilets')
        .snapshots()
        .listen((snapshot) {
      final docs = snapshot.docs;
      // 取得データをリスト／マーカーにマッピング
      final newList = <Map<String, dynamic>>[];
      final newMarkers = <Marker>[];

      for (var doc in docs) {
        final data = doc.data();
        // location フィールドを GeoPoint として取得
        final location = data['location'] as GeoPoint?;
        // location が null でないことを確認
        if (location == null) continue;

        // GeoPoint から緯度と経度を取得
        final lat = location.latitude;
        final lng = location.longitude;

        final entry = {
          'id': doc.id,
          'name': data['name'] as String? ?? '',
          'lat': lat, // 緯度をセット
          'lng': lng, // 経度をセット
          'distance':
              data['distance'] is num ? (data['distance'] as num).toInt() : 0,
          'rating':
              data['rating'] is num ? (data['rating'] as num).toDouble() : 0.0,
          'features': List<String>.from(data['features'] ?? []),
          'address': data['address'] as String? ?? '',
          'cleanliness': data['cleanliness'] is num
              ? (data['cleanliness'] as num).toInt()
              : 0,
          'comments': List<Map<String, dynamic>>.from(data['comments'] ?? []),
          'images': List<String>.from(data['images'] ?? []),
        };
        newList.add(entry);

        newMarkers.add(Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng), // マーカーの位置をセット
          infoWindow: InfoWindow(
            title: entry['name'] as String?,
            snippet: '清潔度: ${entry['cleanliness']}',
            onTap: () {
              // 情報タブに遷移＋選択
              final idx = newList.indexOf(entry);
              setState(() {
                selectedToiletIndex = idx;
                _tabController.animateTo(2);
                _isSidePanelVisible = true; // 詳細表示時にサイドパネルを開く
              });
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            ((entry['cleanliness'] ?? 0) as int) >= 4
                ? BitmapDescriptor.hueBlue
                : BitmapDescriptor.hueRed,
          ),
        ));
      }

      setState(() {
        toiletList = newList;
        _markers = newMarkers;
      });

      // 描画後にカメラを全マーカーにフィット
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _moveToMarkers();
      });
    });
  }

  // 追加: 現在位置を取得して地図を更新するメソッド
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 位置情報サービスが有効かテストします。
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 位置情報サービスが有効でない場合、続行できません。
      // アプリに位置情報サービスを有効にするよう促します。
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('位置情報サービスが無効です。有効にしてください。')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // 権限が拒否された場合、続行できません。
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('位置情報の権限が拒否されました。')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // 権限が永久に拒否されている場合、続行できません。
      // アプリの設定から権限を変更するようユーザーに促します。
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('位置情報の権限が永久に拒否されています。設定から変更してください。')));
      return;
    }

    // ここまで到達した場合、権限が付与されており、
    // デバイスの位置情報にアクセスできます。
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      if (_currentPosition != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                  _currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 15,
            ),
          ),
        );
      }
    } catch (e) {
      print('現在位置の取得に失敗しました: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('現在位置の取得に失敗しました。')));
    }
  }

  // カメラを全マーカーを囲む境界へ移動
  void _moveToMarkers() {
    if (_mapController == null || _markers.isEmpty) return;
    final lats = _markers.map((m) => m.position.latitude);
    final lngs = _markers.map((m) => m.position.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(lats.reduce(min), lngs.reduce(min)),
      northeast: LatLng(lats.reduce(max), lngs.reduce(max)),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  // マップコントローラ取得
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // コントローラ取得後にも一度フィット
    if (_currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 15,
          ),
        ),
      );
    } else {
      // 現在位置がまだ取得できていない場合は、登録マーカーに合わせるか、デフォルト位置のままにする
      _moveToMarkers();
    }
  }

  void _onSelectToilet(int index) {
    setState(() {
      selectedToiletIndex = index;
      _tabController.animateTo(2);
      _isSidePanelVisible = true; // 詳細表示時にサイドパネルを開く
    });
  }

  void _onShowRegisterForm() {
    setState(() {
      _tabController.animateTo(1);
      _isSidePanelVisible = true; // 登録フォーム表示時にサイドパネルを開く
    });
  }

  void _onShowList() {
    setState(() {
      _tabController.animateTo(0);
      _isSidePanelVisible = true; // リスト表示時にサイドパネルを開く
    });
  }

  void _toggleSidePanel() {
    setState(() {
      _isSidePanelVisible = !_isSidePanelVisible;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('トイレマップ口コミサイト'),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: _toggleSidePanel,
        ),
      ),
      body: Row(
        children: [
          // サイドパネル
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: _isSidePanelVisible ? 420 : 0,
            child: SingleChildScrollView(
              child: Container(
                width: 420,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black12)],
                ),
                child: Column(
                  children: [
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
                    Container(
                      height: MediaQuery.of(context).size.height -
                          kToolbarHeight -
                          kBottomNavigationBarHeight -
                          56,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          ToiletListView(
                            toiletList: toiletList,
                            onSelect: _onSelectToilet,
                          ),
                          ToiletRegisterForm(),
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
            ),
          ),
          // 地図エリア
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude,
                            _currentPosition!.longitude)
                        : LatLng(35.68, 139.76),
                    zoom: 15,
                  ),
                  markers: Set<Marker>.of(_markers),
                  myLocationEnabled: true,
                  zoomControlsEnabled: true,
                  padding: EdgeInsets.only(bottom: 56),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FloatingActionButton(
                    heroTag: 'currentLocation',
                    mini: true,
                    child: Icon(Icons.my_location),
                    onPressed: _determinePosition,
                  ),
                ),
                Positioned(
                  top: 70,
                  right: 10,
                  child: FloatingActionButton(
                    heroTag: 'filter',
                    mini: true,
                    child: Icon(Icons.filter_list),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => ToiletFilterDialog(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Container(
          height: 56.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              ElevatedButton.icon(
                icon: Icon(Icons.search),
                label: Text('トイレを探す'),
                onPressed: _onShowList,
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.add_location_alt),
                label: Text('トイレを登録'),
                onPressed: _onShowRegisterForm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
