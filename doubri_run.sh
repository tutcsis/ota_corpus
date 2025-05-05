#!/bin/bash

INPUT_FILES=("data/CC-MAIN-"{a..e}"-phase2.jsonl")
OUTPUT_FILES=("data/CC-MAIN-"{a..e}"-phase3.jsonl")
echo "INPUT_FILES: ${INPUT_FILES[@]}"
echo "OUTPUT_FILES: ${OUTPUT_FILES[@]}"

FLAG_FILES=("${INPUT_FILES[@]/%/.f}")
echo "FLAG_FILES: ${FLAG_FILES[@]}"

INDEX_FILE="./doubri-1.0/indexes/input.index"
DOUBRI_DIR="./doubri-1.0/build"

for INPUT_FILE in "${INPUT_FILES[@]}"; do
  MINHASH_FILE="${INPUT_FILE%.jsonl}.hash"
  # echo "MINHASH_FILE: $MINHASH_FILE"
  "${DOUBRI_DIR}/doubri-minhash" "$MINHASH_FILE" < "$INPUT_FILE"
done


# INPUT_FILE="./data/CC-MAIN-20241101184224-20241101214224-00000-SECOND.jsonl"      # 処理したいJSONLファイル
# OUTPUT_FILE="./data/${BASENAME}-deduplicated.jsonl"

# BASENAME=$(basename "$INPUT_FILE" .jsonl)
# MINHASH_FILE="./data/doubri_minhash/${BASENAME}.hash"
# FLAG_FILE="${MINHASH_FILE}.f"
# INDEX_FILE="./doubri-1.0/indexes/input.index"
# DOUBRI_DIR="./doubri-1.0/build"

# "${DOUBRI_DIR}/doubri-minhash" "$MINHASH_FILE" < "$INPUT_FILE"
# "${DOUBRI_DIR}/doubri-init" "$MINHASH_FILE" > "$FLAG_FILE"
# echo "$MINHASH_FILE" | "${DOUBRI_DIR}/doubri-self" "$INDEX_FILE"
# "${DOUBRI_DIR}/doubri-apply" "$FLAG_FILE" < "$INPUT_FILE" > "$OUTPUT_FILE"

# echo "finished!!  OUTPUT_FILE: $OUTPUT_FILE"