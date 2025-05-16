LINE_START=1
LINE_END=100
LINES=$(seq -s " " ${LINE_START} ${LINE_END})
WARC_URL="https://data.commoncrawl.org/crawl-data/CC-MAIN-2025-08/warc.paths.gz"

GPUQOPTS="-q gLrchq -l select=1:ncpus=1:mem=4G:ngpus=1"
DOCKER_IMAGE="imc.tut.ac.jp/transformers-pytorch-cuda118:4.37.2"

echo "LINES: ${LINES}"
echo "WARC_URL: ${WARC_URL}"

echo "Start step1 jobs.."
for line in ${LINES}; do
  qsub ${GPUQOPTS} -N single_warc_step1_line${line} -k doe -j oe -o ./log -v DOCKER_IMAGE=${DOCKER_IMAGE},curr_line=${line},WARC_URL=${WARC_URL} single_warc_step1.sh
  sleep 3
done
