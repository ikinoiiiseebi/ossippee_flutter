import 'package:flutter/material.dart';

// 2. トイレ登録フォーム
class ToiletRegisterForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onRegister;

  const ToiletRegisterForm({required this.onRegister});

  @override
  State<ToiletRegisterForm> createState() => _ToiletRegisterFormState();
}

class _ToiletRegisterFormState extends State<ToiletRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  String? name;
  String? address;
  double cleanliness = 3;
  List<String> features = [];
  String? comment;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("トイレの写真", style: TextStyle(fontWeight: FontWeight.bold)),
            OutlinedButton.icon(
              icon: Icon(Icons.image),
              label: Text("画像を追加"),
              onPressed: () {
                // image picker
              },
            ),
            SizedBox(height: 20),
            TextFormField(
              decoration: InputDecoration(labelText: "トイレ名 (任意)"),
              onSaved: (v) => name = v,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: "住所"),
              onSaved: (v) => address = v,
            ),
            SizedBox(height: 16),
            Text("清潔度", style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              min: 1,
              max: 5,
              divisions: 4,
              value: cleanliness,
              label: '${cleanliness.round()}',
              onChanged: (v) => setState(() => cleanliness = v),
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
              onSaved: (v) => comment = v,
            ),
            SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                child: Text("登録する"),
                onPressed: () {
                  _formKey.currentState?.save();
                  widget.onRegister({
                    'name': name ?? '',
                    'address': address ?? '',
                    'cleanliness': cleanliness.round(),
                    'features': features,
                    'comment': comment ?? '',
                    // 仮の値
                    'lat': 35.68,
                    'lng': 139.76,
                    'distance': 100,
                    'rating': cleanliness,
                    'comments': [],
                    'images': [],
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String feature) {
    final isSelected = features.contains(feature);
    return FilterChip(
      label: Text(feature),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            features.add(feature);
          } else {
            features.remove(feature);
          }
        });
      },
    );
  }
}
