# Ota Corpus
有害度判定分類機作成のために有害データのデータセットを作成する。
Swallow Corpus 作成を参考にした(https://github.com/swallow-llm/swallow-corpus)

CommonCrawl のデータを使用してフィルタリングを行い、データセットを作成する(https://data.commoncrawl.org/crawl-data/index.html)

# 事前準備
## 1. warc ファイル一覧のテキストファイルを取得
  Commom Crawl warc download url: (https://data.commoncrawl.org/crawl-data/CC-MAIN-2025-13/warc.paths.gz)
- `.gz` ファイルをダウンロードして、解凍する。
- その後、`.txt` ファイルに変更する。
- 取得したテキストファイルは 9 万行ある
```txt
crawl-data/CC-MAIN-2025-08/segments/1738831951398.56/warc/CC-MAIN-20250206114225-20250206144225-00000.warc.gz
crawl-data/CC-MAIN-2025-08/segments/1738831951398.56/warc/CC-MAIN-20250206114225-20250206144225-00001.warc.gz
crawl-data/CC-MAIN-2025-08/segments/1738831951398.56/warc/CC-MAIN-20250206114225-20250206144225-00002.warc.gz
crawl-data/CC-MAIN-2025-08/segments/1738831951398.56/warc/CC-MAIN-20250206114225-20250206144225-00003.warc.gz
crawl-data/CC-MAIN-2025-08/segments/1738831951398.56/warc/CC-MAIN-20250206114225-20250206144225-00004.warc.gz
```

## 2. ライブラリのインストール
以下のライブラリを poetry 仮想環境下に導入
- trafilatura
- warcio
- dartsclone


# Phase 1: テキスト抽出
- WARC ファイルをダウンロードする (12m 程度)
- ダウンロードした WARC ファイルに warc2raw.py を実行して日本語ページを検出し、HTML コンテンツからテキストを抽出する(2m 程度)

CC-MAIN-20250206114225-20250206144225-00095-phase1.jsonl
```json
{
  "url": "http://190930t235409-dot-nakasake-shop.appspot.com/%E7%A7%8B%E7%94%B0-%E7%A7%8B%E7%94%B0%E9%86%B8%E9%80%A0%E6%A0%AA%E5%BC%8F%E4%BC%9A%E7%A4%BE/%E3%82%86%E3%81%8D%E3%81%AE%E7%BE%8E%E4%BA%BA-%E7%B4%94%E7%B1%B3%E5%90%9F%E9%86%B8-%E3%81%97%E3%81%BC%E3%82%8A%E3%81%9F%E3%81%A6%E7%94%9F-R02BY-1800ml",
  "title": "ゆきの美人 純米吟醸 しぼりたて生&nbsp;[R02BY]&nbsp;[1,800&nbsp;mL] - 取手の地酒や 中村酒店", 
  "nanigo": 64.75111224048524,
  "text": "ページを再読み込みして再度お試しください。\n不明なエラーが発生しました。ページを再読み込みして再度お試しください。\nこの状態が継続する場合は、shop@nakamurasaketen.comまでお知らせください。\nカートの内容が変更されていますので、このページを更新します。\n5秒後に自動で更新されます。更新されない場合はこちらをクリックしてください。"
}
```

# Phase2: 品質注釈
- 各テキストの `info` フィールドに評価指標を追加する
- 指標を使用して、「繰り返しの多い Web ページの削除」と「品質の良い日本語の文章を含むウェブページの選定」を行っている
- annotate.py を実行して、指標追加と選定を行っている

# Phase3: 重複削除
- Common Crawl は同一のウェブサイトを異なる時期に巡回・収集しているため、内容が類似したウェブサイトを含んでいる
- C++ の外部ツール `doubri` を使用
  - 総当たり計算は時間がかかるため、Minhash による重複削除を行っている
  - 重複したウェブサイトは古い方を削除
  - 以下のコマンドを poetry 仮想環境下で `build` してから使用
  ```sh
  cmake -S . -B build
  cmake --build build
  ```
  - `doubri` は処理がいくつかあるのでそれぞれ実行する

## 1. doubri-minhash
- jsonl ファイルから MinHash バケットを生成し、指定のファイルに格納(`.hash` が好ましい)
- `MINHASH_FILE`: MinHash バケットを保存するファイルのパス。ファイルを開くことはできない。例: `data/doubri_minhash/data/doubri_minhash/CC-MAIN-20250206114225-20250206144225/00000.hash`
- `INPUT_FILE`: 重複削除元の JSONL ファイル。例: `data/phase2/CC-MAIN-20250206114225-20250206144225-00000-phase2.jsonl`
```sh
doubri-minhash MINHASH_FILE < INPUT_FILE
```

## 2. doubri-init
- MinHash ファイルに対応するフラグファイルを初期化する(`.hash.f` が好ましい)
- フラグはテキストの数だけあり、非重複なら `1` 、重複なら `0` を表す。初期状態は `1`
- `FLAG_FILE`: 重複かどうかを示すフラグを格納しておくファイルのパス。`MINHASH_FILE` と同じフォルダに格納する必要がある。
```sh
doubri-init MINHASH_FILE > FLAG_FILE
```

## 3. doubri-self
- ファイル間の重複削除を行いたいが、コーパスを作成するために必要な JSONL のファイル数がとてつもなく多く、そのままでは重複削除ができない。
- まずある程度の数の JSONL ファイル同士で重複削除を行い、それを一つの `Group` とする。`Group` 内の MinHash データをソートして格納した index ファイルが生成される。これをすべての `Group` で行う。
- なお、重複箇所は指定した hash ファイルと同じファイル名のフラグファイル重複箇所にあたるフラグを `0` に変更する。

- `INDEX_FILE`: `Group` 内の MinHash データをソートして格納したパス。例: `data/doubri_indexes/group_0/input.index`
- `GROUP_FILE`: `Group` 内のすべての MinHash データのパスが 1 行ごとに格納されているテキストファイル(`.txt`)。例: `/work/s245302/ota_corpus/data/doubri_groups/group_0.txt`
```sh
doubri-self INDEX_FILE < GROUP_FILE
```

## 4. doubri-other
- `Group` 内の重複削除が終わったので、次は `Group` 間の重複削除を行う。
- `doubri-self` と同様に、フラグファイルの重複箇所に当たるフラグを `0` に変更する
- `INDEX_FILE` と `GROUP_FILE` のインデックスが同じものを同時に引数として渡してはいけない(`Group` 内のすべてのデータが重複判定になってしまうため)
- `GROUP_FILE` のインデックスは `INDEX_FILE` のインデックスよりも大きくする必要がある(小さいインデックスのデータに関してはこれまでの `doubri-other` の処理で重複判定済みであるため)

```sh
doubri-other INDEX_FILE-1 GROUP_FILE-2 GROUP_FILE-3 ...GROUP_FILE-K
doubri-other INDEX_FILE-2 GROUP_FILE-3 GROUP_FILE-4 ...GROUP_FILE-K
..
doubri-other INDEX_FILE-K-1 GROUP_FILE-K
```

## 5. doubri-apply
- `FLAG_FILE` のフラグが `1` のドキュメント (非重複データ) を抽出する
- `OUTPUT_FILE`: 重複削除後の JSONL ファイルパス。例: `data/phase3/CC-MAIN-20250206114225-20250206144225-00000-phase3.jsonl`
```sh
doubri-apply FLAG_FILE < INPUT_FILE > OUTPUT_FILE
```

# Phase4: 変更
- 各文書の内容を以下のように変更 (クリーニングプロセス)
  - 句読点の正規化 (西洋式句読点 `．，` を日本式句読点 `。、` に変更)
  - 日本語のWebページのフッターをトリミング (`footer.py` の `footers` ヘンスに記載のキーワードを使用)
- `INPUT_FILE`: クリーニングプロセス適用前の JSONL ファイルのパス
- `OUTPUT_FILE`: クリーニングプロセス適用後の JSONL ファイルのパス
```sh
python modify.py < INPUT_FILE > OUTPUT_FILE
```

# 並列処理
- コーパス作成に使用するデータファイルの数がとても多いため、並列処理を用いて一つあたりのジョブの作業量を減らして実行時間を少しでも短縮させたい
- しかし、ファイルを跨いだ処理が存在するのでジョブの完了待ちが発生する。
- 今回は次のように分割した。各ジョブは Group ごとに分割して行った。
1. phase1, phase2, phase3(`doubri-minhash`, `doubri-init`, `doubri-self`): `doubri-self` が各 Group ごとで実行しているため他の処理も Group 単位で実行
2. phase3(`doubri-other`): 処理にすべての Group の MinHash ファイルが必須なので、すべてのジョブが完了するのを待ってから実行。
3. phase3(`doubri-apply`), phase4: ジョブが増え過ぎるのを防止するために、こちらも Group 単位で実行
