#PBS -q gLrchq
#PBS -l select=1:ncpus=4:mem=64G:ngpus=1
#PBS -v DOCKER_IMAGE=imc.tut.ac.jp/transformers-pytorch-cuda118:4.37.2
#PBS -k doe -j oe -o ./log

cd ${PBS_O_WORKDIR}

TORCH_HOME=/lwork/${LOGNAME}/.cache/torch
TRANSFORMERS_CACHE=/lwork/${LOGNAME}/.cache/transformers
HF_HOME=/lwork/${LOGNAME}/.cache/huggingface
TRITON_CACHE_DIR=/lwork/${LOGNAME}/.cache/triton
export TORCH_HOME TRANSFORMERS_CACHE HF_HOME TRITON_CACHE_DIR

START_TIME=$(date +%s)
echo "seg step start: $(date)"

GROUP_LEN=100
WARC_CORPUS_LIST="data/warc_corpus_list.txt"
WARC_HEAD=$(sed -n "17p" "data/commoncrawl_urls.txt")
WARC_URL="https://data.commoncrawl.org/crawl-data/${WARC_HEAD}/warc.paths.gz"
WARC_NAME=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1)_warc_paths
TOTAL_LINE=$(wc -l < "data/${WARC_NAME}.txt")
GROUP_SIZE=$((TOTAL_LINE / GROUP_LEN))

mkdir -p "data/texts/${WARC_HEAD}"

for group_i in $(seq 0 13); do
  WARC_PREFIX=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1 |\
    sed -n $((group_i*GROUP_SIZE+1))p data/$(cat)_warc_paths.txt | basename $(cat) .warc.gz |\
    sed -E 's/-[0-9]{5}$//'
  )
  mkdir -p "data/texts/${WARC_HEAD}/${WARC_PREFIX}"
  echo PREFIX: ${WARC_PREFIX} 
  for i in $(seq 0 $((GROUP_SIZE-1))); do
    WARC_INDEX=$(printf "%05d" $i)
    poetry run python get_texts_sample.py \
      --warc_head="${WARC_HEAD}" \
      --warc_prefix="${WARC_PREFIX}" \
      --warc_index="${WARC_INDEX}" \
      --group_i="${group_i}"
  done
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "seg step is finished: $(date)"
echo "seg step's time: $((DURATION / 3600))hours, $((DURATION % 3600 / 60))minutes, $((DURATION % 60))seconds"


mv "./log/${PBS_JOBID}.OU" "./log/${PBS_JOBNAME}.o${PBS_JOBID%.xregistry*}"
