from tap import Tap
import json

class Args(Tap):
  input_path: str = "data/phase4/sample-phase4.jsonl"
  limit: int = 1

def read_jsonl(file_path):
  with open(file_path, 'r', encoding='utf-8') as file:
    for line in file:
      line = line.strip()
      if line:
        yield json.loads(line)

def main(args):
  print("Loading arguments...")
  count = 0
  for item in read_jsonl(args.input_path):
    if count >= args.limit:
      break
    print(item["text"])
    print("------")
    count += 1

if __name__ == '__main__':
  args = Args().parse_args()
  print(f"Input path: {args.input_path}")
  main(args)
