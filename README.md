# Source code for Swallow Corpus Version 1

This repository provides Python implementation for building Swallow Corpus Version 1, a large Japanese web corpus (Okazaki et al., 2024), from Common Crawl archives.

Common Crawl archives consists of a very large number of WARC files. Each WARC file stores multiple web pages; for example, [CC-MAIN-20230527223515-20230528013515-00000.warc.gz](https://data.commoncrawl.org/crawl-data/CC-MAIN-2023-23/segments/1685224643388.45/warc/CC-MAIN-20230527223515-20230528013515-00000.warc.gz) includes 39,135 web pages.

The construction process is divided into four phases:

1. Text extraction: Extracting Japanese documents (text) from WARC files
2. Quality annotation: Annotating quality assessment to each document
3. Deduplication: Removing redundant documents in the document collection
4. Modification: Cleaning the content of each document

The tasks of phases 1, 2, 4 are independent of documents. Therefore, it is easy to parallerize the processing for (any chunk of) documents by using an external tool (e.g., GNU parallel). For example, we can parallerize the tasks for each WARC file as a unit to speed up the corpus construction.

The corpus is represented in JSONL format, where each line presents a document (web page). The four phases consistently use the same JSONL format. Each line in a JSONL file stores a dictionary object with these fields:

+ `url`: URL of the web page
+ `title`: Title of the web page
+ `text`: Content (text) of the web page
+ `nanigo`: Japanese score (positive for Japanese; negative for non-Japanese)
+ `info`: Quality annotation for the web page (added by Phase 2; see Phase 2 for detail)

The implementations are rather straightforward and simple without any dependency of a special infrastructure for data parallelism (e.g., Spark) or a database. It may take more than a month to build a Japanese web corpus even on servers with a lot of CPU cores, main memory, and large storage. The most time-consuming parts are downloading a very large number of WARC files and deduplication.

## Phrase 1: Text extraction

This tool assumes that WARC files have already downloaded from Common Crawl. Run `warc2raw.py` to detect Japanese pages and extract text from HTML contents.
The script `warc2raw.py` receives a list of gzipped WARC files (`*.warc.gz`) from STDIN and writes gzipped JSON files (`*.jsonl.gz`) to the same directory of each WARC file.

Usage:

```bash
find -name 'CC-MAIN*.warc.gz' | python warc2raw.py
```

Each line of an output file contains a dictionary object (encoded in JSON) with fields:

+ `url`: URL of the web page
+ `title`: Title of the web page
+ `text`: Content (text) of the web page
+ `nanigo`: Japanese score (positive for Japanese; negative for non-Japanese)

## Phase 2: Quality annotation

This phase annotates quality assessments to each document. The assessments are stored in `info` field.

Usage:

```bash
python annotate.py [-f] < INPUT.jsonl > OUTPUT.jsonl
```

+ `INPUT.jsonl`: Source documents in JSONL format
+ `OUTPUT.jsonl`: Annotated documents in JSONL format

This tool reads a dictionary of NG words from `ng.dic` and a list of NG hosts from `ng.url.json.gz`.
We will explain how to create these files later.
Adding `-f` to a command-line argument outputs documents that pass the quality filter, removing other documents.

### Text quality annotation

This tool adds these fields under the `info["annotate"]` object for each document.

Japanese specific:

+ `num_letters`: The number of letters in the document
+ `num_hiragana_letters`: The number of hiragana letters in the document
+ `num_katakana_letters`: The number of katakana letters in the document
+ `num_kanji_letters`: The number of kanji letters in the document
+ `num_kuten`: The number of kuten letters (corresponding to "." in English) in the document
+ `num_toten`: The number of toten letters (corresponding to "," in English) in the document
+ `num_japanese_letters`: The number of Japanese letters in the document, which is equals to `num_hiragana_letters + num_katakana_letters + num_kanji_letters + num_kuten + num_toten`.
+ `hiragana_fraction`: The fraction of hiragana letters in Japanese letters.
+ `katakana_fractionP`: The fraction of katakana letters in Japanese letters.
+ `kanji_fraction`: The fraction of kanji letters in Japanese letters.
+ `kuten_fraction`: The fraction of kuten letters in Japanese letters.
+ `toten_fraction`: The fraction of toten letters in Japanese letters.
+ `japanese_fraction`: The fraction of Japanese letters in all letters.
+ `avg_sentence_length`: The mean of the sentence lengths (in letters).
+ `max_sentence_length`: The maximum of the sentence length (in letters).
+ `num_sentences_ending_with_ellipsis`: The number of sentences ending with ellipsis symbols, '・' or '…'.
+ `ellipsis_fraction`: The fraction of sentences ending ellipsis symbols.

Rules from Rae et al. (2022):

+ `duplicate_paragraph_fraction`: The number of lines duplicated in other lines divided by the total number of lines.
+ `duplicate_paragraph_fraction_in_character`: The number of characters in lines that appear in other lines, divided by the total number of characters.
+ `duplicate_sentence_fraction`: The number of sentences duplicated in other sentences divided by the total number of sentences.
+ `duplicate_sentence_fraction_in_character`: The number of characters in sentences that appear in other sentences, divided by the total number of characters.
+ $n \in \{2, 3, 4\}$:
    + `top_{n}gram_character_fraction`: The number of occurrences of the most frequent $n$-gram, divided by the total number of occurrences of all $n$-grams.
+ $n \in \{5, 6, 7, 8, 9, 10\}$:
    + `duplicate_{n}gram_character_fraction`: The total number of occurrences of $n$-grams appearing more than once / The total number of occurrences of all $n$-grams.

Please refer to `apply_v1` function in `annotate_quality.py` for the thresholds for quality filtering.

### NG word filter

This tool adds `info["ngword"]`, which represets the ratio of characters that match NG expressions. The NG expressions are stored in `ng.dic` as a trie structure (implemented in double array). It is necessary to generate a `ng.dic` file from a list of NG expressions.

The current implementation was designed to read NG keywords from files in `contrib/inappropriate-words-ja`, which is distributed in [inappropriate-words-ja](https://github.com/MosasoM/inappropriate-words-ja). Please download the NG keywords in `contrib/inappropriate-words-ja` directory, and run:

```bash
python ngword.py
```

to build `ng.dic`. Swallow Corpus Version 1 uses other NG keywords, but we don't distribute the keyword list in the repository. Please modify `ngword.py` to add custom NG keywords.

### URL filter

This tool adds `info["url"]`, which indicates whether the URL matches an NG host (`False`) or not (`True`). The NG hostnames are stored in `ng.url.json.gz`. It is necessary to generate a `ng.url.json.gz` file from UT1 blocklist and a custom blacklist.

Please download [Blacklists UT1](https://dsi.ut-capitole.fr/blacklists/index_en.php) in `contrib/blacklists` directory, and run:

```bash
python ngurl.py
```

to build `ng.url.json.gz`. Swallow Corpus Version 1 uses an additional list of NG hosts, but we don't distribute the host list in the repository. Please modify `custom-remove-list.txt` to add custom NG hosts.

## Phase 3: Deduplication

This phases removes duplicated documents. This phase is implemented by an external tool in C++: [Doubri](https://github.com/swallow-llm/doubri).

## Phase 4: Modification

This phase cleans the content of each document. Unlike other phases, this phase changes the content of each document. The cleaning process includes:

+ Punctuation normalization (replacing Western-style punctuations "．，" with Japanese-style ones "。、")
+ Trimming footers of Japanese web pages by using Japanese footer keywords (e.g., "この記事へのトラックバック一覧" ("list of trackbacks to this article")) (see `footer` variable in modify_footer.py)

Usage:

```
python modify.py < INPUT.jsonl > OUTPUT.jsonl
```

+ `INPUT.jsonl`: Source documents in JSONL format
+ `OUTPUT.jsonl`: Cleaned documents in JSONL format

This tool does not add any extra field to a document object.

## References

+ Naoaki Okazaki, Kakeru Hattori, Hirai Shota, Hiroki Iida, Masanari Ohi, Kazuki Fujii, Taishi Nakamura, Mengsay Loem, Rio Yokota, and Sakae Mizuki. 2024. Building a Large Japanese Web Corpus for Large Language Models. In *Proceedings of the First Conference on Language Modeling (COLM)*.
+ Jack W. Rae, Sebastian Borgeaud, Trevor Cai, Katie Millican, Jordan Hoffmann, Francis Song, John Aslanides, Sarah Henderson, Roman Ring, Susannah Young, Eliza Rutherford, Tom Hennigan, Jacob Menick, Albin Cassirer, Richard Powell, George van den Driessche, Lisa Anne Hendricks, Maribeth Rauh, Po-Sen Huang, Amelia Glaese, Johannes Welbl, Sumanth Dathathri, Saffron Huang, Jonathan Uesato, John Mellor, Irina Higgins, Antonia Creswell, Nat McAleese, Amy Wu, Erich Elsen, Siddhant Jayakumar, Elena Buchatskaya, David Budden, Esme Sutherland, Karen Simonyan, Michela Paganini, Laurent Sifre, Lena Martens, Xiang Lorraine Li, Adhiguna Kuncoro, Aida Nematzadeh, Elena Gribovskaya, Domenic Donato, Angeliki Lazaridou, Arthur Mensch, Jean-Baptiste Lespiau, Maria Tsimpoukelli, Nikolai Grigorev, Doug Fritz, Thibault Sottiaux, Mantas Pajarskas, Toby Pohlen, Zhitao Gong, Daniel Toyama, Cyprien de Masson d’Autume, Yujia Li, Tayfun Terzi, Vladimir Mikulik, Igor Babuschkin, Aidan Clark, Diego de Las Casas, Aurelia Guy, Chris Jones, James Bradbury, Matthew Johnson, Blake  echtman, Laura Weidinger, Iason Gabriel, William Isaac, Ed Lockhart, Simon Osindero, Laura Rimell, Chris Dyer, Oriol Vinyals, Kareem Ayoub, Jeff Stanway, Lorrayne Bennett, Demis Hassabis, Koray Kavukcuoglu, and Geoffrey Irving. 2021. Scaling language models: Methods, analysis & insights from training Gopher. arXiv:2112.11446.

## Citing this software

Plain text:

```
Naoaki Okazaki, Kakeru Hattori, Hirai Shota, Hiroki Iida, Masanari Ohi, Kazuki Fujii, Taishi Nakamura, Mengsay Loem, Rio Yokota, and Sakae Mizuki. Building a Large Japanese Web Corpus for Large Language Models. In Proceedings of the First Conference on Language Modeling (COLM), October 2024.
```

Bibtex for the COLM paper:

```
@inproceedings{Okazaki:COLM2024,
  title={Building a Large Japanese Web Corpus for Large Language Models},
  author={Naoaki Okazaki and Kakeru Hattori and Hirai Shota and Hiroki Iida and Masanari Ohi and Kazuki Fujii and Taishi Nakamura and Mengsay Loem and Rio Yokota and Sakae Mizuki},
  booktitle="Proceedings of the First Conference on Language Modeling",
  series={COLM},
  pages="(to appear)",
  year="2024",
  month=oct,
  address={University of Pennsylvania, USA},
}
```

Bibtex for the Github page:

```
@misc{Okazaki:COLM2024,
  title={Doubri: C++ implementation of deduplication},
  author={Naoaki Okazaki},
  howpublished={\url{https://github.com/swallow-llm/swallow-corpus}},
  year="2024",
}
```
