#PBS -q gLrchq
#PBS -l select=1:ncpus=4:mem=128G:ngpus=1
#PBS -v DOCKER_IMAGE=imc.tut.ac.jp/transformers-pytorch-cuda118:4.37.2,DOCKER_OPTIONS="--volume=/lwork:/lwork"
#PBS -k doe -j oe -o ./log

cd ${PBS_O_WORKDIR}

TORCH_HOME=/lwork/${LOGNAME}/.cache/torch
TRANSFORMERS_CACHE=/lwork/${LOGNAME}/.cache/transformers
HF_HOME=/lwork/${LOGNAME}/.cache/huggingface
TRITON_CACHE_DIR=/lwork/${LOGNAME}/.cache/triton
export TORCH_HOME TRANSFORMERS_CACHE HF_HOME TRITON_CACHE_DIR

WARC_URL="https://data.commoncrawl.org/crawl-data/CC-MAIN-2025-13/warc.paths.gz"
WARC_NAME=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1)_warc_paths

echo "WARC_NAME: ${WARC_NAME}"
curl -# -o "data/${WARC_NAME}.gz" "${WARC_URL}"
gunzip "data/${WARC_NAME}.gz"
mv "data/${WARC_NAME}" "data/${WARC_NAME}.txt"

WARC_LIST=${WARC_NAME}.txt
echo "WARC_LIST: ${WARC_LIST}"

get_random_warc_path() {
  local total_lines=$(wc -l < "data/${WARC_LIST}")
  local random_line=$((RANDOM % total_lines + 1))
  sed -n "${random_line}p" "data/${WARC_LIST}"
}

get_unique_warc_path() {
  local max_attempts=10000
  local attempts=0
  local path
  local base_name

  while [ $attempts -lt $max_attempts ]; do
    path=$(get_random_warc_path)
    base_name=$(basename "$path" .warc.gz)

    if [ ! -f "data/phase4/${base_name}-phase4.jsonl" ]; then
      echo "$path"
      return 0
    fi
    attempts=$((attempts + 1))
  done
  echo "Failed to find a unique WARC path after $max_attempts attempts." >&2
  exit 1
}


MAX_FILES=1
PROCESSED=0
FAILED=0

echo "Start time: $(date)"
echo "Target file count: $MAX_FILES"

while [ $PROCESSED -lt $MAX_FILES ]; do
  echo "---------------"
  echo "Processing file: ${PROCESSED}/${MAX_FILES}"

  DATA_PATH=$(get_unique_warc_path)
  BASE_NAME=$(basename ${DATA_PATH} .warc.gz)
  echo "DATA_PATH: ${DATA_PATH}, BASE_NAME: ${BASE_NAME}"

  MINHASH_FILE="data/doubri_minhash/${BASE_NAME}-phase2.jsonl"
  FLAG_FILE="${MINHASH_FILE}.f"
  INDEX_FILE="doubri-1.0/indexes/input.index"
  DOUBRI_DIR="doubri-1.0/build"

  echo "Downloading WARC file: ${DATA_PATH}"
  curl -# -o "data/$(basename ${DATA_PATH})" "https://data.commoncrawl.org/${DATA_PATH}"

  echo "Phase 1"
  echo "data/$(basename ${DATA_PATH})" | poetry run python warc2raw.py 

  echo "Phase 2"
  gunzip data/${BASE_NAME}.jsonl.gz
  mv data/${BASE_NAME}.jsonl data/phase1/${BASE_NAME}-phase1.jsonl
  poetry run python annotate.py < data/phase1/${BASE_NAME}-phase1.jsonl > data/phase2/${BASE_NAME}-phase2.jsonl

  echo "Phase 3"
  "${DOUBRI_DIR}/doubri-minhash" "$MINHASH_FILE" < data/phase2/${BASE_NAME}-phase2.jsonl
  "${DOUBRI_DIR}/doubri-init" "$MINHASH_FILE" > "$FLAG_FILE"
  echo "$MINHASH_FILE" | "${DOUBRI_DIR}/doubri-self" "$INDEX_FILE"
  "${DOUBRI_DIR}/doubri-apply" "$FLAG_FILE" < data/phase2/${BASE_NAME}-phase2.jsonl > data/phase3/${BASE_NAME}-phase3.jsonl

  echo "Phase 4"
  poetry run python modify.py < data/phase3/${BASE_NAME}-phase3.jsonl > data/phase4/${BASE_NAME}-phase4.jsonl

  rm -f "data/$(basename ${DATA_PATH})"

  PROCESSED=$((PROCESSED + 1))
  echo "Processed: $PROCESSED, Failed: $FAILED"
  echo "---------------"
done

echo "---------------"
echo "End time: $(date)"
echo "Processed: $PROCESSED, Failed: $FAILED"

mv "./log/${PBS_JOBID}.OU" "./log/${PBS_JOBNAME}.o${PBS_JOBID%.xregistry*}"
