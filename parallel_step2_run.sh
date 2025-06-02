GROUP_LEN=100
# GROUP_SIZE=10

WARC_CORPUS_LIST="data/warc_corpus_list.txt"
WARC_HEAD=$(sed -n "17p" "data/commoncrawl_urls.txt")
WARC_URL="https://data.commoncrawl.org/crawl-data/${WARC_HEAD}/warc.paths.gz"

echo "WARC_HEAD: ${WARC_HEAD}, WARC_URL: ${WARC_URL}"
# WARC_HEAD is CC-MAIN-2023-23

GPUQOPTS="-q gLrchq -l select=1:ncpus=1:mem=4G:ngpus=1"
DOCKER_IMAGE="imc.tut.ac.jp/transformers-pytorch-cuda118:4.37.2"

# set GROUP_SIZE
TOTAL_LINE=$(wc -l < "data/${WARC_NAME}.txt")
GROUP_SIZE=$((TOTAL_LINE / GROUP_LEN))
echo "TOTAL_LINE: ${TOTAL_LINE},GROUP_SIZE: ${GROUP_SIZE}, GROUP_LEN: ${GROUP_LEN}"

echo "Start multi_warc jobs.."
for i in $(seq 0 $((GROUP_LEN-2))); do
  echo "GROUP_INDEX: ${i}"
  qsub ${GPUQOPTS} -N multi_warc_group${i} -k doe -j oe -o ./log -v DOCKER_IMAGE=${DOCKER_IMAGE},GROUP_INDEX=${i},GROUP_SIZE=${GROUP_SIZE},GROUP_LEN=${GROUP_LEN},WARC_HEAD=${WARC_HEAD},WARC_URL=${WARC_URL} multi_warc.sh
done

