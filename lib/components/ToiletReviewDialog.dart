import 'package:flutter/material.dart';

// --- 口コミ投稿ダイアログ ---
class ToiletReviewDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    double rating = 3.0;
    TextEditingController controller = TextEditingController();
    return AlertDialog(
      title: Text("口コミを投稿"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("評価"),
          Slider(
            min: 1,
            max: 5,
            divisions: 4,
            value: rating,
            label: '${rating.round()}',
            onChanged: (v) {},
          ),
          TextField(
            controller: controller,
            decoration: InputDecoration(labelText: "コメント"),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          child: Text("キャンセル"),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: Text("投稿"),
          onPressed: () {
            // 投稿ロジック
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
