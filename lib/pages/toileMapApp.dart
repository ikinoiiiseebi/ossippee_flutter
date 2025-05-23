import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // 追加
import 'dart:html' as html; // 追加: localStorageのため
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

  // 近隣検索関連の追加
  int _nearbyToiletCount = 0;
  bool _isSearchingNearby = false;
  List<Map<String, dynamic>> _filteredToiletList = [];
  List<Marker> _filteredMarkers = [];
  final double _searchRadiusMeters = 1000.0; // 検索半径 (メートル)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _determinePosition();

    FirebaseFirestore.instance
        .collection('toilets')
        .snapshots()
        .listen((snapshot) {
      final docs = snapshot.docs;
      final newList = <Map<String, dynamic>>[];
      final newMarkers = <Marker>[];

      for (var doc in docs) {
        final data = doc.data();
        final location = data['location'] as GeoPoint?;
        if (location == null) continue;

        final lat = location.latitude;
        final lng = location.longitude;

        final entry = {
          'id': doc.id,
          'name': data['name'] as String? ?? '',
          'lat': lat,
          'lng': lng,
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
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: entry['name'] as String?,
            snippet: '清潔度: ${entry['cleanliness']}',
            onTap: () {
              final idx = _isSearchingNearby
                  ? _filteredToiletList.indexOf(entry)
                  : newList.indexOf(entry);
              setState(() {
                selectedToiletIndex = idx;
                _tabController.animateTo(2);
                _isSidePanelVisible = true;
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
        // もし近隣検索中なら、新しいデータで再フィルタリング
        if (_isSearchingNearby) {
          _performFiltering();
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isSearchingNearby && _mapController != null) {
          _moveToMarkers(_markers); // 全マーカーにフィット
        } else if (_isSearchingNearby &&
            _mapController != null &&
            _filteredMarkers.isNotEmpty) {
          _moveToMarkers(_filteredMarkers); // フィルタリングされたマーカーにフィット
        }
      });
    });
  }

  Future<void> _determinePosition({bool moveCamera = true}) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('位置情報サービスが無効です。有効にしてください。')));
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('位置情報の権限が拒否されました。')));
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('位置情報の権限が永久に拒否されています。設定から変更してください。')));
      }
      return;
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      if (moveCamera && _currentPosition != null && _mapController != null) {
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
      // 現在位置が更新されたら、もし近隣検索中なら再フィルタリング
      if (_isSearchingNearby) {
        _performFiltering();
      }
    } catch (e) {
      print('現在位置の取得に失敗しました: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('現在位置の取得に失敗しました。')));
      }
    }
    if (mounted) {
      setState(() {}); // Update UI if needed after getting position
    }
  }

  void _moveToMarkers(List<Marker> markersToFit) {
    if (_mapController == null || markersToFit.isEmpty) return;
    final lats = markersToFit.map((m) => m.position.latitude);
    final lngs = markersToFit.map((m) => m.position.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(lats.reduce(min), lngs.reduce(min)),
      northeast: LatLng(lats.reduce(max), lngs.reduce(max)),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  void _performFiltering() {
    if (_currentPosition == null) {
      // 現在位置がなければフィルタリングできない
      setState(() {
        _filteredToiletList = [];
        _filteredMarkers = [];
        _nearbyToiletCount = 0;
      });
      return;
    }

    final tempFilteredList = <Map<String, dynamic>>[];
    final tempFilteredMarkers = <Marker>[];

    for (int i = 0; i < toiletList.length; i++) {
      final toilet = toiletList[i];
      final marker = _markers[i]; // toiletListと_markersは同じ順序と仮定

      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        toilet['lat'] as double,
        toilet['lng'] as double,
      );

      if (distance <= _searchRadiusMeters) {
        tempFilteredList.add(toilet);
        tempFilteredMarkers.add(marker);
      }
    }
    setState(() {
      _filteredToiletList = tempFilteredList;
      _filteredMarkers = tempFilteredMarkers;
      _nearbyToiletCount = _filteredToiletList.length;
      if (_isSearchingNearby &&
          _mapController != null &&
          _filteredMarkers.isNotEmpty) {
        _moveToMarkers(_filteredMarkers);
      } else if (_isSearchingNearby &&
          _mapController != null &&
          _filteredMarkers.isEmpty) {
        // 近くにトイレがない場合、現在地にズームなど、適切な処理
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                  _currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 14, // 少し広めに表示
            ),
          ),
        );
      }
    });
  }

  Future<void> _searchNearbyToilets() async {
    // まず現在位置を確実に取得
    await _determinePosition(moveCamera: false); // カメラはここでは動かさない

    if (_currentPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('現在位置が取得できませんでした。検索できません。')));
      }
      setState(() {
        _isSearchingNearby = false; // 検索失敗
      });
      return;
    }

    _performFiltering(); // フィルタリングを実行

    setState(() {
      _isSearchingNearby = true;
      _tabController.animateTo(0);
      _isSidePanelVisible = true;
    });

    // フィルタリング結果を待ってからダイアログ表示
    // _performFiltering内でsetStateが呼ばれるので、その完了を待つために一手間加える
    // WidgetsBinding.instance.addPostFrameCallbackなどを検討したが、
    // _nearbyToiletCountが更新された後に表示するのがシンプル
    if (mounted && _nearbyToiletCount > 0) {
      _showNearbySearchResultDialog(_nearbyToiletCount);
    } else if (mounted && _isSearchingNearby) {
      // 検索モードだが0件の場合
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('近くに利用可能なトイレは見つかりませんでした。')));
    }
  }

  void _clearNearbySearch() {
    setState(() {
      _isSearchingNearby = false;
      _nearbyToiletCount = 0;
      _filteredToiletList = [];
      _filteredMarkers = [];
      if (_mapController != null) {
        _moveToMarkers(_markers); // 全マーカーにフィット
      }
    });
  }

  // 追加: 近隣検索結果ダイアログ
  Future<void> _showNearbySearchResultDialog(int count) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // ユーザーがダイアログ外をタップしても閉じない
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('検索結果'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('$count個のトイレが見つかりました。'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('閉じる'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('次へ'),
              onPressed: () {
                final userId = html.window.localStorage['userId'];
                if (userId == 'null' ||
                    userId == null ||
                    userId.trim().isEmpty) {
                  // 未ログイン・未発行
                  print('ユーザーIDが取得できませんでした。ログインまたはユーザー登録が必要です。');
                  // 必要に応じてエラーメッセージをユーザーに表示
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('ユーザーIDが見つかりません。ログインしてください。')));
                  Navigator.of(context).pop(); // ダイアログを閉じる
                  return;
                }

                print(
                    '「次へ」ボタンが押されました。FirestoreのgameStateを更新します。userId: $userId');
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({'gameState': 'react'}).then((_) {
                  print('FirestoreのgameStateをreactに更新しました。');
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('gameStateを更新しました。')));
                }).catchError((error) {
                  print('FirestoreのgameState更新に失敗しました: $error');
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('gameStateの更新に失敗しました: $error')));
                });
                Navigator.of(context).pop(); // ダイアログを閉じる
              },
            ),
          ],
        );
      },
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
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
      _moveToMarkers(_markers);
    }
  }

  void _onSelectToilet(int index) {
    setState(() {
      // isSearchingNearbyに応じて、正しいリストからインデックスを取得
      selectedToiletIndex = index;
      _tabController.animateTo(2);
      _isSidePanelVisible = true;
    });
  }

  void _onShowRegisterForm() {
    setState(() {
      if (_isSearchingNearby) _clearNearbySearch(); // 登録時は全件表示に戻すなど
      _tabController.animateTo(1);
      _isSidePanelVisible = true;
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
    final displayToiletList =
        _isSearchingNearby ? _filteredToiletList : toiletList;
    final displayMarkers = _isSearchingNearby ? _filteredMarkers : _markers;

    return Scaffold(
      appBar: AppBar(
        title: Text('トイレマップ口コミサイト'),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: _toggleSidePanel,
        ),
        actions: [
          if (_isSearchingNearby)
            IconButton(
              icon: Icon(Icons.clear_all),
              tooltip: '近隣検索をクリア',
              onPressed: _clearNearbySearch,
            )
        ],
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
                            toiletList: displayToiletList, // 表示リストを切り替え
                            onSelect: _onSelectToilet,
                          ),
                          ToiletRegisterForm(),
                          selectedToiletIndex != -1 &&
                                  selectedToiletIndex < displayToiletList.length
                              ? ToiletDetailPanel(
                                  toilet: displayToiletList[
                                      selectedToiletIndex], // 表示リストを切り替え
                                )
                              : Center(child: Text("トイレを選択してください")),
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
                  markers: Set<Marker>.of(displayMarkers), // 表示マーカーを切り替え
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
                label: Text(_isSearchingNearby
                    ? '近くのトイレ (${_nearbyToiletCount}件)'
                    : '近くのトイレを探す'),
                onPressed: _searchNearbyToilets, // _onShowList から変更
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
