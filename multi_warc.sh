echo "curr_line: ${curr_line}, WARC_URL: ${WARC_URL}"

# path settings
TORCH_HOME=/work/${LOGNAME}/.cache/torch
TRANSFORMERS_CACHE=/work/${LOGNAME}/.cache/transformers
HF_HOME=/work/${LOGNAME}/.cache/huggingface
TRITON_CACHE_DIR=/work/${LOGNAME}/.cache/triton
cd ${PBS_O_WORKDIR} && \
export TORCH_HOME=${TORCH_HOME} && \
export TRANSFORMERS_CACHE=${TRANSFORMERS_CACHE} && \
export HF_HOME=${HF_HOME} && \
export TRITON_CACHE_DIR=${TRITON_CACHE_DIR} && \
export TORCH_USE_CUDA_DSA=1 && \
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

WARC_NAME=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1)_warc_paths
INDEX_FILE="doubri-1.0/indexes/input.index"
DOUBRI_DIR="doubri-1.0/build"

# Create a list of phase2 hash files
declare -a PHASE2_PATHES
for curr_line in $(seq 1 $line); do
  WARC_PATH=$(sed -n "${curr_line}p" "data/${WARC_NAME}.txt")
  BASE_NAME=$(basename ${WARC_PATH} .warc.gz)
  PHASE2_PATHES+=("data/phase2/${BASE_NAME}-phase2.hash")
done

# phase3(only doubri-self, doubri-other)
"${DOUBRI_DIR}/doubri-self" "$INDEX_FILE" <<< "$(printf "%s\n" "${PHASE2_PATHES[@]}")"
"${DOUBRI_DIR}/doubri-other" "$INDEX_FILE" "${PHASE2_PATHES[@]}"

echo "WARC_URL: ${WARC_URL}, curr_line: ${curr_line}, WARC_NAME: ${WARC_NAME}"
echo "WARC_PATH: ${WARC_PATH}, BASE_NAME: ${BASE_NAME}"
echo "line: ${curr_line}, path: data/phase2/${BASE_NAME}-phase2.jsonl"
echo "PHASE2_PATHES: ${PHASE2_PATHES[@]}"

mv "./log/${PBS_JOBID}.OU" "./log/${PBS_JOBNAME}.o${PBS_JOBID%.xregistry*}"

