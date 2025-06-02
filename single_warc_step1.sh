START_TIME=$(date +%s)
echo "step1 start: $(date)"

echo "GROUP_SIZE: ${GROUP_SIZE}, GROUP_LEN: ${GROUP_LEN}, group_i: ${group_i}"
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

for curr_line in $(seq $((group_i*GROUP_SIZE+1)) $((group_i*GROUP_SIZE+GROUP_SIZE))); do
  WARC_NAME=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1)_warc_paths
  WARC_PATH=$(sed -n "${curr_line}p" "data/${WARC_NAME}.txt")
  BASE_NAME=$(basename ${WARC_PATH} .warc.gz)
  WARC_PREFIX=$(echo ${BASE_NAME} | sed -E 's/-[0-9]{5}$//')
  WARC_INDEX=$(echo ${BASE_NAME} | grep -oP '(?<=-)[0-9]{5}$')
  DOUBRI_DIR="doubri-1.0/build"

  mkdir -p "data/phase1/${WARC_HEAD}/${WARC_PREFIX}"
  mkdir -p "data/phase2/${WARC_HEAD}/${WARC_PREFIX}"
  mkdir -p "data/phase3/${WARC_HEAD}/${WARC_PREFIX}"
  mkdir -p "data/phase4/${WARC_HEAD}/${WARC_PREFIX}"
  mkdir -p "data/doubri_minhash/${WARC_HEAD}/${WARC_PREFIX}"

  # WARC path: crawl-data/CC-MAIN-2025-08/segments/1738831951398.56/warc/CC-MAIN-20250206114225-20250206144225-00000.warc.gz
  # BASE name: CC-MAIN-20250206114225-20250206144225-00000
  # WARC prefix: CC-MAIN-20250206114225-20250206144225
  # WARC index: 00000

  # phase1(downlad warc, convert to jsonl)
  curl -# -o "data/${BASE_NAME}.warc.gz" "https://data.commoncrawl.org/${WARC_PATH}"
  echo "data/${BASE_NAME}.warc.gz" | poetry run python warc2raw.py
  rm -f "data/${BASE_NAME}.warc.gz"
  gunzip "data/${BASE_NAME}.jsonl.gz"
  mv "data/${BASE_NAME}.jsonl" "data/phase1/${WARC_HEAD}/${WARC_PREFIX}/${BASE_NAME}-phase1.jsonl"

  # phase2(annotate jsonl)
  poetry run python annotate.py < "data/phase1/${WARC_HEAD}/${WARC_PREFIX}/${BASE_NAME}-phase1.jsonl" > "data/phase2/${WARC_HEAD}/${WARC_PREFIX}/${BASE_NAME}-phase2.jsonl"

  # phase3(only doubri-minhash, doubri-init, doubri-self)
  "${DOUBRI_DIR}/doubri-minhash" "data/doubri_minhash/${WARC_HEAD}/${WARC_PREFIX}/${WARC_INDEX}.hash" < "data/phase2/${WARC_HEAD}/${WARC_PREFIX}/${BASE_NAME}-phase2.jsonl"
  "${DOUBRI_DIR}/doubri-init" "data/doubri_minhash/${WARC_HEAD}/${WARC_PREFIX}/${WARC_INDEX}.hash" > "data/doubri_minhash/${WARC_HEAD}/${WARC_PREFIX}/${WARC_INDEX}.hash.f"
done

# phase3(only doubri-self)
echo "GROUP_$((group_i))"
mkdir -p "data/doubri_indexes/group_${group_i}"
rm -f "data/doubri_groups/group_${group_i}.txt" && touch "data/doubri_groups/group_${group_i}.txt"
for hash_i in $(seq 0 $((GROUP_SIZE-1))); do
  echo "data/doubri_minhash/${WARC_HEAD}/${WARC_PREFIX}/`printf "%05d" $((group_i*10+hash_i))`.hash" >> "data/doubri_groups/group_${group_i}.txt"
done
"${DOUBRI_DIR}/doubri-self" "data/doubri_indexes/group_${group_i}/input.index" < "data/doubri_groups/group_${group_i}.txt"
echo "GROUP_${group_i} finished"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "step1 is finished: $(date)"
echo "step1's time: $((DURATION / 3600))hours, $((DURATION % 3600 / 60))minutes, $((DURATION % 60))seconds"

mv "./log/${PBS_JOBID}.OU" "./log/${PBS_JOBNAME}.o${PBS_JOBID%.xregistry*}"
