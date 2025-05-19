# WARC_URL="https://data.commoncrawl.org/crawl-data/CC-MAIN-2025-08/warc.paths.gz"
echo "GROUP_INDEX: ${GROUP_INDEX}, GROUP_SIZE: ${GROUP_SIZE}, GROUP_LEN: ${GROUP_LEN}"
echo "WARC_URL: ${WARC_URL}"

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

# pwd
# ls -lh data/hashes/00001.hash
# ls -lh data/doubri_indexes/CC-MAIN-20250206114225-20250206144225/00000/input.index

# phase3(only doubri-other)
# for group_i in $(seq 0 $((GROUP_INDEX))); do
#   echo "GROUP_$((group_i))"
#   rm -f "data/doubri_groups/group_${group_i}.txt" && touch "data/doubri_groups/group_${group_i}.txt"
#   for hash_i in $(seq 0 $((GROUP_SIZE-1))); do
#     echo "data/doubri_minhash/${PREFIX}/`printf "%05d" $((group_i*10+hash_i))`.hash" >> "data/doubri_groups/group_${group_i}.txt"
#   done
#   "${DOUBRI_DIR}/doubri-self" "data/doubri_indexes/group_${group_i}/input.index" < "data/doubri_groups/group_${group_i}.txt"
#   echo "GROUP_${group_i} finished"
# done

for i in $(seq $((group_i+1)) $((GROUP_LEN-1))); do
  echo -n "data/doubri_groups/group_$((i)).txt "
done | "${DOUBRI_DIR}/doubri-other" "data/doubri_indexes/group_${group_i}/input.index $(cat)"



mv "./log/${PBS_JOBID}.OU" "./log/${PBS_JOBNAME}.o${PBS_JOBID%.xregistry*}"

