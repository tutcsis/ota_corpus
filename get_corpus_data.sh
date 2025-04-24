DATA_PATH="crawl-data/CC-MAIN-2024-46/segments/1730477400050.97/warc/CC-MAIN-20241115021900-20241115051900-00896.warc.gz"
BASE_NAME=$(basename ${DATA_PATH} .warc.gz)

MINHASH_FILE="data/doubri_minhash/${BASE_NAME}-phase2.jsonl"
FLAG_FILE="${MINHASH_FILE}.f"
INDEX_FILE="doubri-1.0/indexes/input.index"
DOUBRI_DIR="doubri-1.0/build"


curl -o "data/$(basename ${DATA_PATH})" "https://data.commoncrawl.org/${DATA_PATH}"

echo "data/$(basename ${DATA_PATH})" | python warc2raw.py

gunzip data/${BASE_NAME}.jsonl.gz
python annotate.py < data/${BASE_NAME}.jsonl > data/${BASE_NAME}-phase2.jsonl

"${DOUBRI_DIR}/doubri-minhash" "$MINHASH_FILE" < data/${BASE_NAME}-phase2.jsonl
"${DOUBRI_DIR}/doubri-init" "$MINHASH_FILE" > "$FLAG_FILE"
echo "$MINHASH_FILE" | "${DOUBRI_DIR}/doubri-self" "$INDEX_FILE"
"${DOUBRI_DIR}/doubri-apply" "$FLAG_FILE" < data/${BASE_NAME}-phase2.jsonl > data/${BASE_NAME}-phase3.jsonl

python modify.py < data/${BASE_NAME}-phase3.jsonl > data/${BASE_NAME}-phase4.jsonl
