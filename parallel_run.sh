# LINES=$(seq -s " " 1 2)
LINES="1 2"
WARC_URL="https://data.commoncrawl.org/crawl-data/CC-MAIN-2025-08/warc.paths.gz"

GPUQOPTS="-q gLrchq -l select=1:ncpus=4:mem=64G:ngpus=1"
DOCKER_IMAGE="imc.tut.ac.jp/transformers-pytorch-cuda118:4.37.2"

echo "Start step1 jobs.."
for line in ${LINES}; do
  qsub ${GPUQOPTS} -N single_warc_step1_line${line} -k doe -j oe -o ./log -v DOCKER_IMAGE=${DOCKER_IMAGE},curr_line=${line},WARC_URL=${WARC_URL} single_warc_step1.sh
  sleep 3
done

echo "Waiting for step1 jobs to complete.."
while true; do
  JOB_COUNT=$(qstat -u ${USER} | grep -c "single_warc_step1")
  if [ ${JOB_COUNT} -eq 0 ]; then
    echo "All step1 jobs completed."
    break
  fi
  sleep 60
done

echo "Start multi_warc jobs.."
qsub ${GPUQOPTS} -N multi_warc_line${line} -k doe -j oe -o ./log -v DOCKER_IMAGE=${DOCKER_IMAGE},curr_line=${line},WARC_URL${WARC_URL} multi_warc.sh
sleep 3

while true; do
  JOB_COUNT=$(qstat -u ${USER} | grep -c "multi_warc")
  if [ ${JOB_COUNT} -eq 0 ]; then
    echo "All multi_warc jobs completed."
    break
  fi
  sleep 60
done

echo "Start step2 jobs.."
for line in ${LINES}; do
  qsub ${GPUQOPTS} -N single_warc_step2_line${line} -k doe -j oe -o ./log -v DOCKER_IMAGE=${DOCKER_IMAGE},curr_line=${line},WARC_URL=${WARC_URL} single_warc_step2.sh
  sleep 3
done
