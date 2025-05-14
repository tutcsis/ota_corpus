# WARC_URL="https://data.commoncrawl.org/crawl-data/CC-MAIN-2025-08/warc.paths.gz"
# LINE_END=5
echo "LINE_ID: ${LINE_ID}"
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
PREFIX=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1 |\
  sed -n "1p" "data/$(cat)_warc_paths.txt" | basename $(cat) .warc.gz |\
  sed -E 's/-[0-9]{5}$//'
)
# INDEX_FILE="doubri-1.0/indexes/input.index"
DOUBRI_DIR="doubri-1.0/build"

# move hash files
mkdir -p "data/hashes"
if [ -d "data/doubri_minhash/${PREFIX}" ]; then
  echo "Files found in data/doubri_minhash/${PREFIX}"
  rm -f data/hashes/*
  mv "data/doubri_minhash/${PREFIX}" "data/hashes/"
  echo "Moved files to data/hashes/"
fi

# phase3(only doubri-other)
for curr_id in $(seq $((LINE_ID+1)) $((LINE_END-1))); do
  printf "%05d\n" $curr_id | echo -n "data/hashes/$(cat).hash "
done | "${DOUBRI_DIR}/doubri-other" "data/indexes/${PREFIX}/$(printf "%05d\n" $LINE_ID)/input.index $(cat)"
echo "--------------------"

mv "./log/${PBS_JOBID}.OU" "./log/${PBS_JOBNAME}.o${PBS_JOBID%.xregistry*}"

