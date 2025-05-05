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

# Download the WARC list file if it doesn't exist
WARC_NAME=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1)_warc_paths
if [ ! -f "data/${WARC_NAME}.txt" ]; then
  echo "WARC_NAME: ${WARC_NAME}"
  curl -# -o "data/${WARC_NAME}.gz" "${WARC_URL}"
  gunzip "data/${WARC_NAME}.gz"
  mv "data/${WARC_NAME}" "data/${WARC_NAME}.txt"
fi

WARC_PATH=$(sed -n "${curr_line}p" "data/${WARC_NAME}.txt")
BASE_NAME=$(basename ${WARC_PATH} .warc.gz)
DOUBRI_DIR="doubri-1.0/build"

# phase1, phase2, phase3(only doubri-minhash, doubri-init)
curl -# -o "data/${BASE_NAME}.warc.gz" "https://data.commoncrawl.org/${WARC_PATH}"
echo "data/${BASE_NAME}.warc.gz" | poetry run python warc2raw.py
rm -f "data/${BASE_NAME}.warc.gz"
gunzip "data/${BASE_NAME}.jsonl.gz"
mv "data/${BASE_NAME}.jsonl" "data/phase1/${BASE_NAME}-phase1.jsonl"
poetry run python annotate.py < "data/phase1/${BASE_NAME}-phase1.jsonl" > "data/phase2/${BASE_NAME}-phase2.jsonl"
"${DOUBRI_DIR}/doubri-minhash" "data/phase2/${BASE_NAME}-phase2.jsonl" < "data/phase2/${BASE_NAME}-phase2.jsonl"
"${DOUBRI_DIR}/doubri-init" "data/phase2/${BASE_NAME}-phase2.jsonl" > "data/phase2/${BASE_NAME}-phase2.jsonl.f"

mv "./log/${PBS_JOBID}.OU" "./log/${PBS_JOBNAME}.o${PBS_JOBID%.xregistry*}"