import 'package:flutter/material.dart';

// --- フィルターダイアログ ---
class ToiletFilterDialog extends StatefulWidget {
  @override
  _ToiletFilterDialogState createState() => _ToiletFilterDialogState();
}

class _ToiletFilterDialogState extends State<ToiletFilterDialog> {
  bool isWashletSelected = false;
  bool isMultipurposeSelected = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("トイレ検索フィルター"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            value: isWashletSelected,
            title: Text("ウォシュレット"),
            onChanged: (bool? value) {
              setState(() {
                isWashletSelected = value ?? false;
              });
            },
          ),
          CheckboxListTile(
            value: isMultipurposeSelected,
            title: Text("多目的"),
            onChanged: (bool? value) {
              setState(() {
                isMultipurposeSelected = value ?? false;
              });
            },
          ),
          // ... 他にも設備
        ],
      ),
      actions: [
        TextButton(
          child: Text("リセット"),
          onPressed: () {
            setState(() {
              isWashletSelected = false;
              isMultipurposeSelected = false;
              // 他のフィルターもリセット
            });
          },
        ),
        ElevatedButton(
          child: Text("適用"),
          onPressed: () {
            Navigator.pop(context, {
              'isWashletSelected': isWashletSelected,
              'isMultipurposeSelected': isMultipurposeSelected,
            });
          },
        ),
      ],
    );
  }
}
