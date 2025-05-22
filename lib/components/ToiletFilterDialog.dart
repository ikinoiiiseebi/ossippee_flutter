import 'package:flutter/material.dart';

// --- フィルターダイアログ ---
class ToiletFilterDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("トイレ検索フィルター"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            value: true,
            title: Text("ウォシュレット"),
            onChanged: (_) {},
          ),
          CheckboxListTile(
            value: false,
            title: Text("多目的"),
            onChanged: (_) {},
          ),
          // ... 他にも設備
        ],
      ),
      actions: [
        TextButton(
          child: Text("リセット"),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: Text("適用"),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
