import 'package:flutter/material.dart';

// 1. 検索リスト表示
class ToiletListView extends StatelessWidget {
  final List<Map<String, dynamic>> toiletList;
  final Function(int) onSelect;

  const ToiletListView({
    required this.toiletList,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: toiletList.length,
      itemBuilder: (context, idx) {
        final toilet = toiletList[idx];
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: ListTile(
            leading: Icon(Icons.wc, color: Colors.blue),
            title: Text(toilet['name']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(toilet['address'] ?? ''),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 18),
                    Text('${toilet['cleanliness']}'),
                    SizedBox(width: 12),
                    Text('${toilet['distance']}m'),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: List.generate(
                    toilet['features'].length,
                    (i) => Chip(
                      label: Text(toilet['features'][i]),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () => onSelect(idx),
          ),
        );
      },
    );
  }
}
