WARC_URL="https://data.commoncrawl.org/crawl-data/CC-MAIN-2025-08/warc.paths.gz"
LINE_END=5
echo "LINE_END: ${LINE_END}, WARC_URL: ${WARC_URL}"

# path settings
# TORCH_HOME=/work/${LOGNAME}/.cache/torch
# TRANSFORMERS_CACHE=/work/${LOGNAME}/.cache/transformers
# HF_HOME=/work/${LOGNAME}/.cache/huggingface
# TRITON_CACHE_DIR=/work/${LOGNAME}/.cache/triton
# cd ${PBS_O_WORKDIR} && \
# export TORCH_HOME=${TORCH_HOME} && \
# export TRANSFORMERS_CACHE=${TRANSFORMERS_CACHE} && \
# export HF_HOME=${HF_HOME} && \
# export TRITON_CACHE_DIR=${TRITON_CACHE_DIR} && \
# export TORCH_USE_CUDA_DSA=1 && \
# export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

WARC_NAME=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1)_warc_paths
INDEX_FILE="doubri-1.0/indexes/input.index"
DOUBRI_DIR="doubri-1.0/build"

# Create a list of .hash files
HASH_FILE_ARRAY=()
BASE_NAME_ARRAY=()
for f in `head -n ${LINE_END} "data/${WARC_NAME}.txt"`; do
  HASH_FILE_ARRAY+=(data/doubri_minhash/`basename ${f} .warc.gz`-phase2.hash)
  BASE_NAME_ARRAY+=(`basename ${f} .warc.gz`)
done

for curr_line in $(seq 0 $((LINE_END-2))); do
  echo "index: data/doubri-indexes/${BASE_NAME_ARRAY[$curr_line]}/input.index"
  for line_id in $(seq $((curr_line+1)) $((LINE_END-1))); do echo "${HASH_FILE_ARRAY[$line_id]}"; done | "${DOUBRI_DIR}/doubri-other" "data/doubri-indexes/${BASE_NAME_ARRAY[$curr_line]}/input.index" 
  echo "----------------------------------------"
done

# for hash_file in ${HASH_FILE_ARRAY[@]}; do
#   echo "$hash_file"
# done

# for f in `head -n ${line} ${WARC_PATH}`; do echo data/doubri_minhash/`basename ${f} .warc.gz`-phase2.json.f ; done | "${DOUBLRI_DIR}/doubri-self ${INDEX_FILE}


# phase3(only doubri-other)
# "${DOUBRI_DIR}/doubri-other" "$INDEX_FILE" "${PHASE2_PATHES[@]}"

# echo "WARC_URL: ${WARC_URL}, LINE_END: ${LINE_END}, WARC_NAME: ${WARC_NAME}"
# echo "WARC_PATH: ${WARC_PATH}, BASE_NAME: ${BASE_NAME}"
# echo "line: ${LINE_END}, path: data/phase2/${BASE_NAME}-phase2.jsonl"
# echo "PHASE2_PATHES: ${PHASE2_PATHES[@]}"

# mv "./log/${PBS_JOBID}.OU" "./log/${PBS_JOBNAME}.o${PBS_JOBID%.xregistry*}"

