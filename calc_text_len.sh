
GROUP_LEN=1
GROUP_SIZE=800

WARC_CORPUS_LIST="data/warc_corpus_list.txt"
WARC_HEAD=$(sed -n "17p" "data/commoncrawl_urls.txt")
WARC_URL="https://data.commoncrawl.org/crawl-data/${WARC_HEAD}/warc.paths.gz"
group_i=0
WARC_NAME=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1)_warc_paths
WARC_PREFIX=$(echo "$WARC_URL" | grep -oP "CC-MAIN-\d{4}-\d{2}" | head -1 |\
  sed -n $((group_i*GROUP_SIZE+1))p data/$(cat)_warc_paths.txt | basename $(cat) .warc.gz |\
  sed -E 's/-[0-9]{5}$//'
)



# calc only group0
# names=("phase1" "phase2" "phase3" "phase4" "texts")
path_tail=("")
for phase in {1..4}; do
# for phase in ${names[@]}; do
  file_pattern=data/phase${phase}/${WARC_HEAD}/${WARC_PREFIX}/${WARC_PREFIX}-*-phase${phase}.jsonl
  files=($(ls $file_pattern 2>/dev/null || echo ""))
  if [ ${#files[@]} -gt 0 ]; then
    wc -l ${files[@]} | tail -n 1 |\
    awk -v p=$phase '{print "Phase " p " lines:", $1}'
  else
    echo "No files found for pattern: $file_pattern"
  fi


  # text_len=0
  # for i in $(seq 0 $((GROUP_LEN*GROUP_SIZE-1))); do
  #   file=data/phase${phase}/${WARC_HEAD}/${WARC_PREFIX}/${WARC_PREFIX}-$(printf "%05d" $i)-phase${phase}.jsonl
  #   if [ ! -f $file ]; then
  #     echo "File not found: $phase_file"
  #     continue
  #   fi
  #   text_len+=$(wc -l < "$file")
  #   echo $text_len
  # done
  echo ""
done
