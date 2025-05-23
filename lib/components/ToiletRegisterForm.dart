import 'dart:math'; // Randomのために追加
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:html' as html; // Flutter Webのみ
import 'package:geolocator/geolocator.dart'; // Position を使用するために追加
import 'package:flutter_sound/flutter_sound.dart'; // flutter_sound をインポート
import 'package:permission_handler/permission_handler.dart'; // permission_handler をインポート
// import 'package:path_provider/path_provider.dart'; // Webでの問題を避けるためコメントアウトまたは削除

// 2. トイレ登録フォーム
class ToiletRegisterForm extends StatefulWidget {
  final Position? currentPosition; // 追加

  const ToiletRegisterForm({super.key, this.currentPosition}); // 変更

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

  // 音声ブースト関連
  bool _isRecordingForBoost = false;
  FlutterSoundRecorder? _recorder;
  // String? _recordingPath; // Webでの問題を避けるためコメントアウトまたは削除
  bool _isRecorderInitialized = false;
  double _currentDecibels = 0.0;

  // デフォルトの地図位置（東京駅）
  late LatLng _initialPos; // 変更: initStateで設定

  @override
  void initState() {
    super.initState();
    if (widget.currentPosition != null) {
      _initialPos = LatLng(
          widget.currentPosition!.latitude, widget.currentPosition!.longitude);
      _selectedPosition = _initialPos;
    } else {
      _initialPos = LatLng(35.68, 139.76); // フォールバックとして東京駅
    }
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    _recorder = FlutterSoundRecorder();

    // マイク権限のリクエスト
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('マイクの使用が許可されていません。')),
        );
      }
      return;
    }

    try {
      await _recorder!.openRecorder();
      _isRecorderInitialized = true;
      // デシベル値の更新を購読
      _recorder!
          .setSubscriptionDuration(Duration(milliseconds: 200)); // 200msごとに更新
      _recorder!.onProgress!.listen((e) {
        print(
            'DEBUG: onProgress listener CALLED. Event: ${e.toString()}'); // ★リスナー呼び出し確認用のprint文を追加
        print(
            'Audio Progress: decibels: ${e.decibels}, duration: ${e.duration}'); // DEBUG PRINT
        if (e.decibels != null) {
          if (mounted) {
            // Check if widget is still in the tree
            setState(() {
              _currentDecibels = e.decibels!;
            });
          }
        } else {
          print('Audio Progress: decibels is null'); // DEBUG PRINT
        }
      });
    } catch (e) {
      print('レコーダーの初期化に失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('レコーダーの初期化に失敗しました。')),
        );
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _recorder = null;
    super.dispose();
  }

  // Firestore登録処理
  Future<void> _registerToilet() async {
    final userId = html.window.localStorage['userId'];
    if (userId == 'null' || userId == null || userId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ユーザーIDが取得できません。ログインしてください。')),
      );
      return;
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
        'cleanliness': _cleanliness.round(), // 四捨五入して整数で保存
        'features': _features,
        'comment': _comment ?? '',
        'createdAt': Timestamp.now(),
        'createdBy': userId,
        'images': [],
        'averageRating': _cleanliness.round(), // こちらも合わせておく
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
        _isRecordingForBoost = false; // 状態をリセット
        _currentDecibels = 0.0;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登録に失敗しました: $e')),
      );
    }
  }

  Future<void> _toggleCleanlinessBoost() async {
    if (!_isRecorderInitialized || _recorder == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('レコーダーが準備できていません。')),
        );
      }
      return;
    }

    if (_recorder!.isRecording) {
      // 録音停止
      try {
        await _recorder!.stopRecorder();
        print(
            'Current decibels before boost calculation: $_currentDecibels'); // DEBUG PRINT
        if (mounted) {
          setState(() {
            _isRecordingForBoost = false;
          });
        }

        // デシベル値に基づいてブースト
        double boostFactor = 0.0;
        if (_currentDecibels > -20) {
          boostFactor = 1.5 + Random().nextDouble() * 0.5; // 1.5 ~ 2.0
        } else if (_currentDecibels > -40) {
          boostFactor = 0.5 + Random().nextDouble() * 0.5; // 0.5 ~ 1.0
        } else {
          boostFactor = Random().nextDouble() * 0.5; // 0.0 ~ 0.5
        }

        _cleanliness = (_cleanliness + boostFactor).clamp(1.0, 5.0);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '音量ブースト成功！清潔度が ${_cleanliness.toStringAsFixed(1)} になりました！ (デシベル: ${_currentDecibels.toStringAsFixed(1)}dB)')),
          );
        }
      } catch (e) {
        print('録音停止エラー: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('録音の停止に失敗しました。')),
          );
        }
      }
    } else {
      // 録音開始
      try {
        await _recorder!.startRecorder(
          codec: Codec.opusWebM, // ★コーデックを opusWebM に変更
        );
        if (mounted) {
          setState(() {
            _isRecordingForBoost = true;
            _currentDecibels = 0.0; // 録音開始時にリセット
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('叫び声で評価アップ！もう一度マイクボタンを押して評価！')),
          );
        }
      } catch (e) {
        print('録音開始エラー: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('録音の開始に失敗しました。')),
          );
        }
      }
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
            Text("清潔度 (現在デシベル: ${_currentDecibels.toStringAsFixed(1)}dB)",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              // Rowでスライダーとボタンを配置
              children: [
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 5,
                    divisions: 40,
                    value: _cleanliness,
                    label: '${_cleanliness.toStringAsFixed(1)}',
                    onChanged: (v) {
                      setState(() {
                        _cleanliness = v;
                        if (_recorder?.isRecording ?? false) {
                          _recorder?.stopRecorder();
                        }
                        _isRecordingForBoost = false;
                        _currentDecibels = 0.0;
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(_isRecordingForBoost
                      ? Icons.stop_circle_outlined
                      : Icons.mic),
                  color: _isRecordingForBoost
                      ? Colors.red
                      : Theme.of(context).primaryColor,
                  tooltip: _isRecordingForBoost ? '評価を確定' : '音声で清潔度ブースト！',
                  onPressed:
                      _isRecorderInitialized ? _toggleCleanlinessBoost : null,
                ),
              ],
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
