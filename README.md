# ossippee_flutter

## デプロイ方法

webアプリとしてデプロイしてください
出来上がったものは`build/web`に出来上がります
また、base hrefを修正するために以下のようにオプションをつけてください

```
flutter build web --release --base-href "/web/"
```

出来上がったファイル`build/web`の中身を全てReactプロジェクトの`public`下において下さい

