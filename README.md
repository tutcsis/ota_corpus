# Ota Corpus
有害度判定分類機作成のために有害データのデータセットを作成する。
Swallow Corpus 作成を参考にした(https://github.com/swallow-llm/swallow-corpus)

CommonCrawl のデータを使用してフィルタリングを行い、データセットを作成する(https://data.commoncrawl.org/crawl-data/index.html)
## 1. まず、warc ファイルのパスが記載されているテキストファイルを取得する(https://data.commoncrawl.org/crawl-data/CC-MAIN-2025-13/warc.paths.gz)
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

## 2. 全てのパスに対して次の処理を行う (実行の際は並列で処理を行う)
### warc ファイルのダウンロード
- 取得したテキストファイルから、warc ファイルのパスを取得してダウンロードする (ダウンロードしたものは `.warc.gz` ファイル)。

### Phase 1
- テキスト抽出: WARC ファイルから日本語文書 (テキスト) を抽出 (`.jsonl.gz` ファイルが出力される)
- 出力された `.jsonl.gz` ファイルを解凍して、`.jsonl` にする (`.jsonl` ファイルはフェーズ毎で格納先を分けたいので `data/phase1` フォルダに格納する)。
- 元の `.warc.gz` ファイルはもう使用しないので、削除する。

### Phase 2
- 品質アノテーション: 繰り返し表現の多いテキストの削除、品質の悪い文章が基準よりも多いテキストを削除
- Phase 1 で出力された `.jsonl` ファイルを使用して品質アノテーションを行う (`.jsonl` ファイルが出力される)。

### Phase 3
- 重複削除: ファイル内のテキストの重複の削除、ファイルを跨いだテキストの重複削除
- `doubri` というツールを `build` して使用 (https://github.com/swallow-llm/doubri)
- Phase 2 で出力された `.jsonl` ファイルを使用して重複削除を行う (`.jsonl` ファイルが出力される)。
  1. `doubri-minhash`: `.jsonl` ファイルから MinHash バケットを作成し、`.hash` ファイルとして出力
  2. `doubri-init`: `.hash` ファイルからフラグをテキストの数だけ作成 (初期値は `1`) し、`.f` として出力(フラグファイルの中身は `111..11` のようになっている)
  3. `doubri-self`: `.hash`, `.f` ファイル (渡すのは `.hash` のみ) からファイル内の重複箇所に当たるフラグを `1` から `0` に変更する。その後、インデックスファイルを `.index` として `r = 40` 個出力する(例: `input.index.00013`)。
    - Group: データファイルをある程度の数でまとめたもの。`doubri-self`, `doubri-other` では、この Group ごと関数にパスを渡す

- 結果として、各データに対してそれぞれ対応する `.hash`, `.f`, `.index` ファイルが生成されている。

## 3. 全てのファイルに対して順に実行する (生成物の `.index` ファイルを別の `.hash` ファイルの処理に使用するため)

### Phase 3
- ファイル間の重複削除を行う
  4. `doubri-other`: 重複判定の基準となる `.index` ファイル一つと重複対象となる (判定が未完了である) そのほかの `.hash` ファイルを使用。
  - 全ての `.hash`, `.index` が存在すれば、それぞれの`doubri-other` は同時に実行してもいい(それぞれが干渉しない)

- この処理を全ての `.index` ファイルに対して実行する。
- 渡すものは `1.index`, `{2..N}.hash` -> `2.index`, `{3..N}.hash` .. -> `{N-1}.index`, `N.hash` と変化する。
- これにより最終的な `.f` ファイルが生成されている 。

```sh
for curr_line in $(seq 0 $((LINE_END-2))); do
  echo "index: data/doubri-indexes/${BASE_NAME_ARRAY[$curr_line]}/input.index"
  for line_id in $(seq $((curr_line+1)) $((LINE_END-1))); do echo "${HASH_FILE_ARRAY[$line_id]}"; done | "${DOUBRI_DIR}/doubri-other" "data/doubri-indexes/${BASE_NAME_ARRAY[$curr_line]}/input.index" 
  echo "----------------------------------------"
done
```
doubri-other に投げる順番
```txt
index: data/doubri-indexes/CC-MAIN-20250206114225-20250206144225-00000/input.index
data/doubri_minhash/CC-MAIN-20250206114225-20250206144225-00001-phase2.hash
data/doubri_minhash/CC-MAIN-20250206114225-20250206144225-00002-phase2.hash
data/doubri_minhash/CC-MAIN-20250206114225-20250206144225-00003-phase2.hash
data/doubri_minhash/CC-MAIN-20250206114225-20250206144225-00004-phase2.hash
----------------------------------------
index: data/doubri-indexes/CC-MAIN-20250206114225-20250206144225-00001/input.index
data/doubri_minhash/CC-MAIN-20250206114225-20250206144225-00002-phase2.hash
data/doubri_minhash/CC-MAIN-20250206114225-20250206144225-00003-phase2.hash
data/doubri_minhash/CC-MAIN-20250206114225-20250206144225-00004-phase2.hash
----------------------------------------
index: data/doubri-indexes/CC-MAIN-20250206114225-20250206144225-00002/input.index
data/doubri_minhash/CC-MAIN-20250206114225-20250206144225-00003-phase2.hash
data/doubri_minhash/CC-MAIN-20250206114225-20250206144225-00004-phase2.hash
----------------------------------------
index: data/doubri-indexes/CC-MAIN-20250206114225-20250206144225-00003/input.index
data/doubri_minhash/CC-MAIN-20250206114225-20250206144225-00004-phase2.hash
----------------------------------------
```

## 4. 全てのパスに対して次の処理を行う (実行の際は並列で処理を行う)

### Phase 3
  5. `doubri-apply`: フラグファイルを渡し、さらに標準入力として元の `.jsonl` ファイルを渡すとフラッグが `1` の行のみが標準出力で指定した `.jsonl` として出力される。

### Phase 4
- 修正: 句読点を `．，` から `。、` への変更、ヘッダーのトリミング
- Phase 3 で出力された `.jsonl` ファイルを使用してテキストの修正を行う (`.jsonl` ファイルが出力される)。

## Phase 3 の実行例
- 使用する `.jsonl` ファイルを 100 個とする。
- Group は 10 個で、それぞれが 10 ファイルあるとする。
  - Group0: `00000.jsonl`, `00001.jsonl`, `00002.jsonl`, `00003.jsonl`, `00004.jsonl`, `00005.jsonl`, `00006.jsonl`, `00007.jsonl`, `00008.jsonl`, `00009.jsonl`
  - Group1: `00010.jsonl`, `00011.jsonl`, `00012.jsonl`, `00013.jsonl`, `00014.jsonl`, `00015.jsonl`, `00016.jsonl`, `00017.jsonl`, `00018.jsonl`, `00019.jsonl`
  ..
  - Group9: `00090.jsonl`, `00091.jsonl`, `00092.jsonl`, `00093.jsonl`, `00094.jsonl`, `00095.jsonl`, `00096.jsonl`, `00097.jsonl`, `00098.jsonl`, `00099.jsonl`
- `data/doubri_groups/group0.txt` などにはそれぞれ各グループが所属する hash ファイルのパスを格納

### doubri-self
- index ファイル: `data/doubri_indexes/group0/input.index`
- hash ファイル: `data/doubri_minhash/00000.hash`, `data/doubri_minhash/00001.hash`, ..`data/doubri_minhash/00009.hash`
これを全ての Group に対して繰り返す

- 重複削除の確認のために、自分で 5 個程度重複テキストに置き換える
- group0:  `00001.jsonl`, ..., `00005.jsonl` の 5行目のテキストを `00000.jsonl` の 5 行目のテキストに置き換える
- もう一度 phase1 から実行
- `.f` ファイル, `log` を確認
```00001.hash.f
1111011111
```
```00002.hash.f
1111011111
```
```00003.hash.f
1111011111
```
```00004.hash.f
1111011111
```
```00005.hash.f
1111011110
```
- このように、`00001.jsonl`, ..., `00005.jsonl` の 5 行めの重複が全てできていた

### doubri-other
- index ファイル: `data/doubri_indexes/group0/input.index`
- group ファイル : `data/doubri_groups/group0.txt`, `data/doubri_groups/group1.txt`, ..`data/doubri_groups/group9.txt`
これを全ての index ファイル (今回はグループ数 = 10 なので 10 回) に対して繰り返す

- 重複削除確認のために、自分で 5 個程度重複テキストに置き換える。
- group1: `00010.jsonl` の 5行目のテキストを `00000.jsonl` の 5 行目のテキストに置き換える
- group2: `00020.jsonl` の 5行目のテキストを `00000.jsonl` の 5 行目のテキストに置き換える
- group3: `00030.jsonl` の 5行目のテキストを `00000.jsonl` の 5 行目のテキストに置き換える
- group4: `00040.jsonl` の 5行目のテキストを `00000.jsonl` の 5 行目のテキストに置き換える
- group5: `00050.jsonl` の 5行目のテキストを `00000.jsonl` の 5 行目のテキストに置き換える

```00010.hash.f
1111111111
```
```00020.hash.f
1111111111
```
```00030.hash.f
1111111111
```
```00040.hash.f
1111111111
```
```00050.hash.f
1111111111
```
- このように、重複削除はできていなかった。
**考えうる原因**
- 各 group のパスが間違えている
- group_1.txt の中身が間違えている(現在は `.hash`)
- index ファイルのパスが間違えている
- index ファイルの中身が壊れている(ファイルを開くことができないので確認できない)
