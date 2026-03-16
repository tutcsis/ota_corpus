from tap import Tap
import json
import functools

from ja_sentence_segmenter.common.pipeline import make_pipeline
from ja_sentence_segmenter.concatenate.simple_concatenator import concatenate_matching
from ja_sentence_segmenter.normalize.neologd_normalizer import normalize
from ja_sentence_segmenter.split.simple_splitter import split_newline, split_punctuation

class Args(Tap):
  input_path: str = ""
  output_path: str = ""
  warc_head: str = ""
  warc_prefix: str = ""
  warc_index: str = ""
  group_i: int = 0

def read_jsonl(file_path):
  with open(file_path, 'r', encoding='utf-8') as file:
    for line in file:
      line = line.strip()
      if line:
        yield json.loads(line)

def write_text(file_path, texts):
  with open(file_path, 'w', encoding='utf-8') as o_file:
    for text in texts:
      o_file.write(f"{text}\n")


def main(args):
  print("Loading arguments...")
  # input_path, output_path
  args.input_path = f"data/phase4/{args.warc_head}/{args.warc_prefix}/{args.warc_prefix}-{args.warc_index}-phase4.jsonl"
  args.output_path = f"data/texts/{args.warc_head}/{args.warc_prefix}/{args.warc_index}-ja-sentence.txt"
  
  split_punc2 = functools.partial(split_punctuation, punctuations=r"。!?")
  concat_tail_no = functools.partial(concatenate_matching, former_matching_rule=r"^(?P<result>.+)(の)$", remove_former_matched=False)
  segmenter = make_pipeline(normalize, split_newline, concat_tail_no, split_punc2)

  texts = []
  count = 0
  for item in read_jsonl(args.input_path):
    texts.extend(list(segmenter(item["text"].replace("\n", ""))))
    count += 1
  
  print(f"Total segments: {len(texts)}")
  write_text(args.output_path, texts)
  
if __name__ == '__main__':
  args = Args().parse_args()
  print(f"Input path: {args.input_path}")
  main(args)
