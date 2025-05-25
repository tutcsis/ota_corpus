LINE_START=1
LINE_END=10
GROUP_SIZE=10
GROUP_LEN=10
LINE_IDS=$(seq -s " " $((LINE_START-1)) $((LINE_END-1)))
WARC_URL="https://data.commoncrawl.org/crawl-data/CC-MAIN-2025-08/warc.paths.gz"

GPUQOPTS="-q gLrchq -l select=1:ncpus=1:mem=4G:ngpus=1"
DOCKER_IMAGE="imc.tut.ac.jp/transformers-pytorch-cuda118:4.37.2"

PREFIX=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1 |\
  sed -n "1p" "data/$(cat)_warc_paths.txt" | basename $(cat) .warc.gz |\
  sed -E 's/-[0-9]{5}$//'
)

echo LINE_IDS: ${LINE_IDS}
echo WARC_URL: ${WARC_URL}

JOB_COUNT=$(qstat -u ${USER} | grep -c "single_war")
if [ ${JOB_COUNT} -ne 0 ]; then
  echo "All step1 jobs are still running!!. Job count: ${JOB_COUNT}"
  exit 1
fi

# rm -f data/hashes/*
# # copy hash files
# if [ `find data/hashes/ -type f | wc -l` -eq 0 ]; then
#     cp -rf "data/doubri_minhash/${PREFIX}/"* "data/hashes/"
#     cp -rf "data/doubri_flag/${PREFIX}/"* "data/hashes/"
#     echo "No files found in data/hashes/"
#     echo "WARC_PREFIX: ${PREFIX}"
# fi
echo "Start multi_warc jobs.."
for i in $(seq 0 $((GROUP_LEN-2))); do
  echo "GROUP_INDEX: ${i}"
  qsub ${GPUQOPTS} -N multi_warc_group${i} -k doe -j oe -o ./log -v DOCKER_IMAGE=${DOCKER_IMAGE},GROUP_INDEX=${i},GROUP_SIZE=${GROUP_SIZE},GROUP_LEN=${GROUP_LEN},WARC_URL=${WARC_URL} multi_warc.sh
done

# for i in ${LINE_IDS}; do
#   qsub ${GPUQOPTS} -N multi_warc_line${i} -k doe -j oe -o ./log -v DOCKER_IMAGE=${DOCKER_IMAGE},LINE_ID=${i},LINE_END=${LINE_END},WARC_URL=${WARC_URL} multi_warc.sh
# done
