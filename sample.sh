curr_line=1
WARC_URL="https://data.commoncrawl.org/crawl-data/CC-MAIN-2025-08/warc.paths.gz"

WARC_NAME=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1)_warc_paths
WARC_PATH=$(sed -n "${curr_line}p" "data/${WARC_NAME}.txt")
BASE_NAME=$(basename ${WARC_PATH} .warc.gz)

PREFIX=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1 |\
  sed -n "1p" "data/$(cat)_warc_paths.txt" | basename $(cat) .warc.gz |\
  sed -E 's/-[0-9]{5}$//'
)
echo "prefix: ${PREFIX}"
LINE_START=1
LINE_END=5

LINES=$(seq -s " " $((LINE_START-1)) $((LINE_END-1)))
echo "LINES: ${LINES}"

# for i in $(seq 0 ${LINE_END}); do
#   printf "%05d\n" $i
# done

# separate WARC path
WARC_PREFIX=$(echo ${BASE_NAME} | sed -E 's/-[0-9]{5}$//')
WARC_INDEX=$(echo ${BASE_NAME} | grep -oP '(?<=-)[0-9]{5}$')

for i in $(seq 0 $((LINE_END-1))); do
  # echo "index: data/indexes/${PREFIX}/$(printf "%05d\n" $i)/input.index"
  # hash_texts=""
  # for line_id in $(seq $((i+1)) $((LINE_END-1))); do
  #   hash_texts="${hash_texts} $(printf "%05d\n" $line_id).hash"
  # done
  # echo "HASH_TEXT: ${hash_texts}"
  for line_id in $(seq $((i+1)) $((LINE_END-1))); do
    printf "%05d\n" $line_id | echo -n "data/hashes/$(cat).hash "
  done | echo "data/indexes/${PREFIX}/$(printf "%05d\n" $i)/input.index $(cat)"
  echo "--------------------"
done


echo "WARC name: ${WARC_NAME}"
echo "WARC path: ${WARC_PATH}"
echo "WARC prefix: ${WARC_PREFIX}"
echo "WARC number: ${WARC_INDEX}"
echo "BASE name: ${BASE_NAME}"
echo "---------------------------"
echo "HASH: data/doubri_minhash/${WARC_PREFIX}/${WARC_INDEX}.hash"
echo "FLAG: data/doubri_flag/${WARC_PREFIX}/${WARC_INDEX}.f"
echo "INDEX: data/doubri_indexes/${WARC_PREFIX}/${WARC_INDEX}/input.index"
echo "---------------------------"
echo "phase1: data/phase1/${BASE_NAME}-phase1.jsonl"
echo "phase2: data/phase2/${BASE_NAME}-phase2.jsonl"
echo "phase3: data/phase3/${BASE_NAME}-phase3.jsonl"
echo "phase4: data/phase4/${BASE_NAME}-phase4.jsonl"
echo "---------------------------"

