LINE_START=1
LINE_END=100
LINE_IDS=$(seq -s " " $((LINE_START-1)) $((LINE_END-1)))
WARC_URL="https://data.commoncrawl.org/crawl-data/CC-MAIN-2025-08/warc.paths.gz"

GPUQOPTS="-q gLrchq -l select=1:ncpus=4:mem=64G:ngpus=1"
DOCKER_IMAGE="imc.tut.ac.jp/transformers-pytorch-cuda118:4.37.2"

echo LINE_IDS: ${LINE_IDS}
echo WARC_URL: ${WARC_URL}

JOB_COUNT=$(qstat -u ${USER} | grep -c "single_war")
if [ ${JOB_COUNT} -ne 0 ]; then
  echo "All step1 jobs are still running!!. Job count: ${JOB_COUNT}"
  exit 1
fi

echo "Start multi_warc jobs.."
for i in ${LINE_IDS}; do
  qsub ${GPUQOPTS} -N multi_warc_line${LINE_END} -k doe -j oe -o ./log -v DOCKER_IMAGE=${DOCKER_IMAGE},LINE_ID=${i},LINE_END=${LINE_END},WARC_URL=${WARC_URL} multi_warc.sh
done
