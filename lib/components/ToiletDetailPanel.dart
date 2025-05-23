import 'package:flutter/material.dart';
import './ToiletReviewDialog.dart';

// 3. 詳細パネル
class ToiletDetailPanel extends StatelessWidget {
  final Map<String, dynamic> toilet;

  const ToiletDetailPanel({required this.toilet});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(toilet['name'], style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8),
          Text(toilet['address']),
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber),
              Text('${toilet['cleanliness']}'),
              SizedBox(width: 16),
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
          Divider(height: 32),
          Text("口コミ", style: TextStyle(fontWeight: FontWeight.bold)),
          ...(toilet['comments'] is List
              ? toilet['comments']
                  .map<Widget>((c) => ListTile(
                        leading: Icon(Icons.person),
                        title: Text(c['user']),
                        subtitle: Text(c['comment']),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 18),
                            Text('${c['rating']}'),
                          ],
                        ),
                      ))
                  .toList()
              : []),
          OutlinedButton.icon(
            icon: Icon(Icons.add_comment),
            label: Text("口コミを投稿"),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ToiletReviewDialog(),
              );
            },
          ),
        ],
      ),
    );
  }
}
