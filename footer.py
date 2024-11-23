# Remove footers based on keywords.
#   Copyright (c) 2023-2024 by Naoaki Okazaki, MIT license

footers = """
この記事へのトラックバック一覧
無断転載を禁じ
無断転載を禁ず
Sponsored Link
Comments
記事
最近記事
Copyright
©
All right reserved
All rights reserved
スポンサー
固定リンク
トップページ
コメント
Inc.
その他
PR
クリック
受け取る
サイト
いいね
ツイート
共有
全部見る
http
コメント
Reserved
Rights
rights
reserved
問い合わせ
トラックバック
Twitter
twitter
ポイント
Follow
アフィリエイト
問い合わせ
ランキング
sponsored
リンク
link
クリックお願い
一覧へ
詳細表示
特定商取引法に基づく表記
プライバシーポリシー
サイトポリシー
サイト利用規約
サイトマップ
ご利用規約
このサイトについて
会社概要
会社案内
ヘルプ
資料請求
お知らせ
管理者ページ
検索
サイト内検索
プロフィール
ピックアップ
一覧を見る
広告掲載
マイページ
ログイン
ログアウト
バナー
新規登録
新規会員登録
トピックス
"""

footer_words = list(set(w for w in footers.split("\n") if w))
footer_words.sort(key=lambda x: len(x), reverse=True)

def is_footer(line: str, p: float, ng_words: list):
    num_matched_letters = 0
    num_total_letters = len(line)
    for ng_word in ng_words:
        before = len(line)
        line = line.replace(ng_word, '')
        num_matched_letters += (before - len(line))
    ratio = num_matched_letters / num_total_letters if 0 < num_total_letters else 0.
    return p < ratio

def trim_footer(text: str, n: int, p: float, footer_words: list):
    lines = text.split('\n')
    for i in range(max(0, len(lines)-n), len(lines)):
        if is_footer(lines[i], p, footer_words):
            break
    else:
        i = len(lines)
    return '\n'.join(lines[:i])

def apply(text):
    return trim_footer(text, n=10, p=0.3, footer_words=footer_words)
