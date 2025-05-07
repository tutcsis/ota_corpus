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
WARC_PATH=$(sed -n "${curr_line}p" "data/${WARC_NAME}.txt")
BASE_NAME=$(basename ${WARC_PATH} .warc.gz)
DOUBRI_DIR="doubri-1.0/build"

# phase3(only doubri-apply), phase4, delete .warc.gz file
"${DOUBRI_DIR}/doubri-apply" "data/doubri_minhash/${BASE_NAME}-phase2.jsonl.f" < "data/phase2/${BASE_NAME}-phase2.jsonl" > "data/phase3/${BASE_NAME}-phase3.jsonl"
poetry run python modigy.py < "data/phase3/${BASE_NAME}-phase3.jsonl" > "data/phase4/${BASE_NAME}-phase4.jsonl"

mv "./log/${PBS_JOBID}.OU" "./log/${PBS_JOBNAME}.o${PBS_JOBID%.xregistry*}"
