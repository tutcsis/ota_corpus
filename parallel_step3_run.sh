LINE_START=1
LINE_END=100
LINES=$(seq -s " " ${LINE_START} ${LINE_END})
WARC_URL="https://data.commoncrawl.org/crawl-data/CC-MAIN-2025-08/warc.paths.gz"

GPUQOPTS="-q gLrchq -l select=1:ncpus=4:mem=64G:ngpus=1"
DOCKER_IMAGE="imc.tut.ac.jp/transformers-pytorch-cuda118:4.37.2"

echo "LINES: ${LINES}"
echo "WARC_URL: ${WARC_URL}"

JOB_COUNT=$(qstat -u ${USER} | grep -c "multi_warc")
if [ ${JOB_COUNT} -ne 0 ]; then
  echo "All step2 jobs are still running!!. Job count: ${JOB_COUNT}"
  exit 1
fi

echo "Start step2 jobs.."
for line in ${LINES}; do
  qsub ${GPUQOPTS} -N single_warc_step2_line${line} -k doe -j oe -o ./log -v DOCKER_IMAGE=${DOCKER_IMAGE},curr_line=${line},WARC_URL=${WARC_URL} single_warc_step2.sh
  sleep 3
done
