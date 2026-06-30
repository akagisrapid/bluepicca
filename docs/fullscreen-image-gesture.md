# フルスクリーン画像ビューのジェスチャー設計

`FullScreenImageView` / `ZoomableImageView` における画像操作の設計メモ。

## 構成

```
FullScreenImageView          — 複数枚ページング、dismiss ジェスチャー管理
└─ ZoomableImageView (×N)   — 個別画像のズーム・パン担当
```

## ZoomableImageView の状態変数

| 変数 | 役割 |
|------|------|
| `scale` | 現在の表示倍率（1.0 = 等倍、最大 5.0） |
| `lastScale` | ピンチジェスチャー開始時点の倍率（累積用） |
| `offset` | 現在のパン量 |
| `lastOffset` | ドラッグジェスチャー開始時点のパン量（累積用） |
| `isPinching` | ピンチ中フラグ（DragGesture 誤発動防止） |

## ジェスチャー設計

### SimultaneousGesture の構成

`MagnificationGesture` と `DragGesture` を `SimultaneousGesture` で同時認識する。

```
SimultaneousGesture(
    MagnificationGesture(minimumScaleDelta: 0.05),  // ピンチ
    DragGesture(minimumDistance: 4)                  // パン / ページ送り / dismiss
)
```

- `minimumScaleDelta: 0.05` — 微小な指の開閉をピンチと誤認識しない
- `minimumDistance: 4` — タップとドラッグを区別し、微小な誤ドラッグを無視

### ピンチ操作（MagnificationGesture）

`value` はジェスチャー開始時を 1.0 とした比率。累積のため `lastScale` と掛け合わせる。

```
scale = lastScale * value
```

**ラバーバンド効果**: `proposed < 1.0`（等倍以下に縮もうとした）場合は係数 0.15 で抵抗感を与え、視覚的縮小を抑える。

```
scale = 1.0 + (proposed - 1.0) * 0.15
```

`onEnded` で `scale <= 1.0` なら `withAnimation(.spring())` で等倍・中央位置にスナップバック。

### パン操作（DragGesture、ズーム中）

`scale > 1` のときはパン操作として扱い、オフセットを計算する。

画像が画面外に出ないよう `GeometryReader` で取得したビューサイズを元に上限を設定：

```
maxX = viewWidth  * (scale - 1) / 2
maxY = viewHeight * (scale - 1) / 2
offset.x = clamp(lastOffset.x + translation.x, -maxX, maxX)
offset.y = clamp(lastOffset.y + translation.y, -maxY, maxY)
```

`scale = 2` なら X 上限は viewWidth / 2、`scale = 3` なら viewWidth。拡大率に比例。

### ページ送り / dismiss（DragGesture、等倍時）

`scale == 1` のときは `ZoomableImageView` でのドラッグを親の `FullScreenImageView` に委譲する。

- 横ドラッグ → ページ送り（`onDrag` / `onDragEnd` コールバック）
- 縦ドラッグ（下方向）→ dismiss

### ピンチとドラッグの干渉防止

`SimultaneousGesture` ではピンチ終了時に `DragGesture.onEnded` も同一フレームで呼ばれる。
`scale <= 1` にリセットした直後に `onDragEnd` が呼ばれると、dismiss やページ送りが誤発動する。

これを防ぐため `isPinching` フラグを 0.1 秒遅延して `false` にする：

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    isPinching = false
}
```

`DragGesture.onChanged` / `onEnded` の冒頭で `guard !isPinching else { return }` により弾く。

### ダブルタップ

- 等倍（`scale == 1`）→ 2倍にズーム
- ズーム中 → 等倍・中央位置にリセット

## ページング設計（FullScreenImageView）

- `HStack` に全画像を並べ、`offset(x:)` でページを切り替える
- ズーム中（`isAnyImageZoomed == true`）は横ドラッグが `ZoomableImageView` 側で消費されるため、ページ送りは発生しない
- `isAnyImageZoomed` は `@Binding` で各 `ZoomableImageView` と共有

## dismiss 設計

下方向ドラッグ中は `dismissOffset` でビュー全体を下にずらし、背景の `opacity` を連動して暗くする。
指を離したとき `dy > 120` or `predictedHeight > 300` なら dismiss、そうでなければ元の位置に戻る。
