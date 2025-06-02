START_TIME=$(date +%s)
echo "step1 start: $(date)"

echo "GROUP_SIZE: ${GROUP_SIZE}, GROUP_LEN: ${GROUP_LEN}, group_i: ${group_i}, WARC_URL: ${WARC_URL}"

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

for curr_line in $(seq $((group_i*GROUP_SIZE+1)) $((group_i*GROUP_SIZE+GROUP_SIZE))); do
  WARC_PATH=$(sed -n "${curr_line}p" "data/${WARC_NAME}.txt")
  BASE_NAME=$(basename ${WARC_PATH} .warc.gz)
  WARC_PREFIX=$(echo ${BASE_NAME} | sed -E 's/-[0-9]{5}$//')
  WARC_INDEX=$(echo ${BASE_NAME} | grep -oP '(?<=-)[0-9]{5}$')
  DOUBRI_DIR="doubri-1.0/build"

  # phase3(only doubri-apply), phase4
  "${DOUBRI_DIR}/doubri-apply" "data/doubri_minhash/${WARC_PREFIX}/${WARC_INDEX}.hash.f" < "data/phase2/${WARC_PREFIX}/group_${group_i}/${BASE_NAME}-phase2.jsonl" > "data/phase3/${WARC_PREFIX}/group_${group_i}/${BASE_NAME}-phase3.jsonl"
  poetry run python modify.py < "data/phase3/${WARC_PREFIX}/group_${group_i}/${BASE_NAME}-phase3.jsonl" > "data/phase4/${WARC_PREFIX}/group_${group_i}/${BASE_NAME}-phase4.jsonl"
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "step1 is finished: $(date)"
echo "step1's time: $((DURATION / 3600))hours, $((DURATION % 3600 / 60))minutes, $((DURATION % 60))seconds"


mv "./log/${PBS_JOBID}.OU" "./log/${PBS_JOBNAME}.o${PBS_JOBID%.xregistry*}"
