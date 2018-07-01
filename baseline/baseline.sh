#!/bin/bash

[ "$#" -ge 2 ] || { echo Usage: $0 input_dataset output_directory >&2; exit 1; }

input="$1"
output="$2"
workdir=/home/conll18-baseline/baseline

cat "$input"/metadata.json | python3 -c "
import sys,json
for entry in json.load(sys.stdin):
    print(' '.join([entry['lcode'], entry['tcode'], entry['rawfile'], entry['outfile']]))
" | while read lcode tcode in out; do
      code=${lcode}_${tcode}
      model=`grep "^$code " $workdir/baseline_mapping.txt | head -n1 | cut -d" " -f2`
      if [ -z "$model" ]; then
        echo Unknown model for $code, trying any $lcode model.
	  model=`grep "^${lcode}_" $workdir/baseline_mapping.txt | head -n1 | cut -d" " -f2`
	  [ -z "$model" ] && { echo Unknown model for $code or $lcode >&2; exit 1; }
      fi

      echo Processing $code with model $model
      time $workdir/udpipe --tokenize --tag --parse $workdir/models/$model-ud-2.2-conll18-180430.udpipe $input/$in --outfile $output/$out
done

echo All done
