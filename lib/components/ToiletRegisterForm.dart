import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:html' as html; // Flutter Webのみ

// 2. トイレ登録フォーム
class ToiletRegisterForm extends StatefulWidget {
  const ToiletRegisterForm({super.key});

  @override
  State<ToiletRegisterForm> createState() => _ToiletRegisterFormState();
}

class _ToiletRegisterFormState extends State<ToiletRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  String? _name;
  double _cleanliness = 3;
  List<String> _features = [];
  String? _comment;
  LatLng? _selectedPosition;

  // デフォルトの地図位置（東京駅）
  final LatLng _initialPos = LatLng(35.68, 139.76);

  // Firestore登録処理
  Future<void> _registerToilet() async {
    final userId = html.window.localStorage['userId'];
    if (userId == 'null' || userId == null || userId.trim().isEmpty) {
      // 未ログイン・未発行
      // 新しいIDを発行する、またはエラー・認証誘導
    }
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('マップ上でピンの位置を選択してください')),
      );
      return;
    }
    try {
      final toilets = FirebaseFirestore.instance.collection('toilets');
      await toilets.add({
        'name': _name ?? '',
        'location':
            GeoPoint(_selectedPosition!.latitude, _selectedPosition!.longitude),
        'cleanliness': _cleanliness.round(),
        'features': _features,
        'comment': _comment ?? '',
        'createdAt': Timestamp.now(),
        'createdBy': userId,
        'images': [],
        'averageRating': _cleanliness,
        'commentCount': 0,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('トイレを登録しました')),
      );
      setState(() {
        _formKey.currentState?.reset();
        _selectedPosition = null;
        _features = [];
        _cleanliness = 3;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登録に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("マップ上のピンをドラッグして位置を決めてください",
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Container(
              height: 220,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedPosition ?? _initialPos,
                  zoom: 16,
                ),
                markers: {
                  Marker(
                    markerId: MarkerId('selected'),
                    position: _selectedPosition ?? _initialPos,
                    draggable: true,
                    onDragEnd: (newPos) {
                      setState(() => _selectedPosition = newPos);
                    },
                  ),
                },
                onTap: (pos) {
                  setState(() => _selectedPosition = pos);
                },
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(labelText: "トイレ名（任意）"),
              onSaved: (v) => _name = v,
            ),
            SizedBox(height: 16),
            Text("清潔度", style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              min: 1,
              max: 5,
              divisions: 4,
              value: _cleanliness,
              label: '${_cleanliness.round()}',
              onChanged: (v) => setState(() => _cleanliness = v),
            ),
            SizedBox(height: 16),
            Text("設備", style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: [
                _buildFeatureChip("ウォシュレット"),
                _buildFeatureChip("洋式"),
                _buildFeatureChip("和式"),
                _buildFeatureChip("多目的"),
                _buildFeatureChip("オムツ交換台"),
                _buildFeatureChip("子供用便座"),
                _buildFeatureChip("トイレットペーパー"),
              ],
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(labelText: "一言コメント"),
              maxLines: 2,
              onSaved: (v) => _comment = v,
            ),
            SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                child: Text("登録する"),
                onPressed: () {
                  _formKey.currentState?.save();
                  _registerToilet();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String feature) {
    final isSelected = _features.contains(feature);
    return FilterChip(
      label: Text(feature),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _features.add(feature);
          } else {
            _features.remove(feature);
          }
        });
      },
    );
  }
}
