START_TIME=$(date +%s)
echo "step1 start: $(date)"

echo "GROUP_INDEX: ${GROUP_INDEX}, GROUP_SIZE: ${GROUP_SIZE}, GROUP_LEN: ${GROUP_LEN}"
echo "WARC_HEAD: ${WARC_HEAD}, WARC_URL: ${WARC_URL}"

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
PREFIX=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1 |\
  sed -n "1p" "data/$(cat)_warc_paths.txt" | basename $(cat) .warc.gz |\
  sed -E 's/-[0-9]{5}$//'
)
# INDEX_FILE="doubri-1.0/indexes/input.index"
DOUBRI_DIR="doubri-1.0/build"

# phase3(only doubri-other)
args=("data/doubri_indexes/group_${GROUP_INDEX}/input.index")
for i in $(seq $((GROUP_INDEX+1)) $((GROUP_LEN-1))); do
  args+=("data/doubri_groups/group_${i}.txt")
done
echo "args: ${args[@]}"
"${DOUBRI_DIR}/doubri-other" "${args[@]}"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "step1 is finished: $(date)"
echo "step1's time: $((DURATION / 3600))hours, $((DURATION % 3600 / 60))minutes, $((DURATION % 60))seconds"

mv "./log/${PBS_JOBID}.OU" "./log/${PBS_JOBNAME}.o${PBS_JOBID%.xregistry*}"
