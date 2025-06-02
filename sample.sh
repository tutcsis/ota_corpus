curr_line=1
WARC_URL="https://data.commoncrawl.org/crawl-data/CC-MAIN-2025-08/warc.paths.gz"

WARC_NAME=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1)_warc_paths
WARC_PATH=$(sed -n "${curr_line}p" "data/${WARC_NAME}.txt")
BASE_NAME=$(basename ${WARC_PATH} .warc.gz)

PREFIX=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1 |\
  sed -n "1p" "data/$(cat)_warc_paths.txt" | basename $(cat) .warc.gz |\
  sed -E 's/-[0-9]{5}$//'
)
# echo "prefix: ${PREFIX}"
LINE_START=1
LINE_END=100

LINES=$(seq -s " " $((LINE_START-1)) $((LINE_END-1)))
# echo "LINES: ${LINES}"

# for i in $(seq 0 ${LINE_END}); do
#   printf "%05d\n" $i
# done

# separate WARC path
WARC_PREFIX=$(echo ${BASE_NAME} | sed -E 's/-[0-9]{5}$//')
WARC_INDEX=$(echo ${BASE_NAME} | grep -oP '(?<=-)[0-9]{5}$')
WARC_HEAD=$(sed -n "17p" "data/commoncrawl_urls.txt")
echo "WARC_PREFIX: ${WARC_PREFIX}, WARC_INDEX: ${WARC_INDEX}, WARC_HEAD: ${WARC_HEAD}"
# WARC_PREFIX: CC-MAIN-20250206114225-20250206144225
# WARC_INDEX: 00000
# WARC_HEAD: CC-MAIN-2023-23
echo "${WARC_HEAD}/${WARC_PREFIX}"

# phase1~4 run sample
# python annotate.py < "data/phase1/sample-phase1.jsonl" > "data/phase2/sample-phase2.jsonl"
# python modify.py < "data/phase2/sample-phase2.jsonl" > "data/phase4/sample-phase4.jsonl"




# for i in $(seq 0 $((LINE_END-1))); do
#   # echo "index: data/indexes/${PREFIX}/$(printf "%05d\n" $i)/input.index"
#   # hash_texts=""
#   # for line_id in $(seq $((i+1)) $((LINE_END-1))); do
#   #   hash_texts="${hash_texts} $(printf "%05d\n" $line_id).hash"
#   # done
#   # echo "HASH_TEXT: ${hash_texts}"
#   for line_id in $(seq $((i+1)) $((LINE_END-1))); do
#     printf "%05d\n" $line_id | echo -n "data/hashes/$(cat).hash "
#   done | echo "data/indexes/${PREFIX}/$(printf "%05d\n" $i)/input.index $(cat)"
#   echo "--------------------"
# done
# for curr_id in $(seq $((LINE_START)) $((LINE_END-1))); do
#   printf "%05d\n" $curr_id | echo -n "data/hashes/$(cat).hash "
# done | echo data/indexes/${PREFIX}/$(printf "%05d\n" $((LINE_START-1)))/input.index $(cat)

# curr_id=0
# for curr_id in $(seq $((LINE_ID+1)) $((LINE_END-1))); do
#   printf "%05d\n" $curr_id | echo -n "data/hashes/$(cat).hash "
# done | echo data/indexes/${PREFIX}/$(printf "%05d\n" $LINE_ID)/input.index $(cat)

GROUP_INDEX=2
GROUP_LEN=100

# check line count of warc list file
WARC_NAME=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1)_warc_paths
TOTAL_LINES=$(wc -l < "data/${WARC_NAME}.txt")
GROUP_SIZE=$((TOTAL_LINES / GROUP_LEN))
echo "TOTAL_LINE: ${TOTAL_LINE},GROUP_SIZE: ${GROUP_SIZE}, GROUP_LEN: ${GROUP_LEN}"



## doubri-self
# for group_i in $(seq 0 $((GROUP_INDEX-1))); do
#   echo "GROUP_$((group_i))"
  # rm -f "data/doubri_groups/group_${group_i}.txt" && touch "data/doubri_groups/group_${group_i}.txt"
  # for hash_i in $(seq 0 $((GROUP_SIZE-1))); do
  #   echo "data/doubri_minhash/${WARC_PREFIX}/`printf "%05d" $((group_i*10+hash_i))`.hash" >> "data/doubri_groups/group_${group_i}.txt"
  # done
  # while read line; do
  #   echo "$line"
  # done < "data/doubri_groups/group_${group_i}.txt"
#   for curr_line in $(seq $((group_i*GROUP_SIZE+1)) $(((group_i+1)*GROUP_SIZE))); do
#     echo $curr_line
#   done
#   echo "GROUP_${group_i} finished"
# done

## doubi-other
# group_i=8
# for i in $(seq $((group_i+1)) $((GROUP_LEN-1))); do
#   echo -n "data/doubri_groups/group_$((i)).txt "
# done | echo "data/doubri_indexes/group_${group_i}/input.index $(cat)"

# rm -f data/hashes/*
# for i in ${LINES}; do
#   echo $i
#   if [ `find data/hashes/ -type f | wc -l` -eq 0 ]; then
#     cp -rf "data/doubri_minhash/${WARC_PREFIX}/"* "data/hashes/"
#     echo "No files found in data/hashes/"
#     echo "WARC_PREFIX: ${WARC_PREFIX}"
#   fi
# done

# check text length of each phase 1-4 file 
# for i in $(seq 0 $((GROUP_LEN*GROUP_SIZE-1))); do
#   file_sizes=()
#   for phase in {1..4}; do
#     phase_file="data/phase${phase}/${WARC_PREFIX}-`printf "%05d" $((i))`-phase${phase}.jsonl"
#     if [ ! -f "$phase_file" ]; then
#       echo "File not found: $phase_file"
#       continue
#     fi
#     file_sizes+=($(wc -l < "$phase_file"))
#     # echo "Phase ${phase} file: $phase_file"
#   done
#   echo "`printf "%05d" $((i))`: $(IFS=,; echo "${file_sizes[*]}"), phase1 and phase4 diff: $((${file_sizes[0]} - ${file_sizes[3]}))"
# done


# echo "WARC name: ${WARC_NAME}"
# echo "WARC path: ${WARC_PATH}"
# echo "WARC prefix: ${WARC_PREFIX}"
# echo "WARC number: ${WARC_INDEX}"
# echo "BASE name: ${BASE_NAME}"
# echo "---------------------------"
# echo "HASH: data/doubri_minhash/${WARC_PREFIX}/${WARC_INDEX}.hash"
# echo "FLAG: data/doubri_flag/${WARC_PREFIX}/${WARC_INDEX}.f"
# echo "INDEX: data/doubri_indexes/${WARC_PREFIX}/${WARC_INDEX}/input.index"
# echo "---------------------------"
# echo "phase1: data/phase1/${BASE_NAME}-phase1.jsonl"
# echo "phase2: data/phase2/${BASE_NAME}-phase2.jsonl"
# echo "phase3: data/phase3/${BASE_NAME}-phase3.jsonl"
# echo "phase4: data/phase4/${BASE_NAME}-phase4.jsonl"
# echo "---------------------------"

