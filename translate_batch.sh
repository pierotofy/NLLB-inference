set -euo pipefail

root=$(dirname $0)
#export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib

usage () {
    echo "usage: $0 ckp slang tlang < input > output" >&2
    exit 1
}

[ $# -eq 4 ] || usage

ckp=$1
slang=$2
tlang=$3
infile=$4

translate () {
    local ckp slang tlang
    ckp=$1
    slang=$2
    tlang=$3
    infile=$4
    bash preprocess/normalize_punctuation.sh $slang < $infile > input.normalized.txt
    spm_encode --model preprocess/flores200_sacrebleu_tokenizer_spm.model input.normalized.txt > input.tokenized.txt

    fairseq-interactive $root --input input.tokenized.txt --quiet -s $slang -t $tlang \
            --path $ckp --batch-size 1024 --max-tokens 8192 --buffer-size 100000 \
            --nbest 1 --beam 4 --lenpen 1.0 \
            --fixed-dictionary $root/dictionary.txt \
            --task translation_multi_simple_epoch \
            --decoder-langtok --encoder-langtok src \
            --langs $(cat $root/langs.txt) \
            --lang-pairs $slang-$tlang \
            --add-data-source-prefix-tags > output.fairseq.txt

    cat output.fairseq.txt | grep -P '^H-' | sed 's/H-//' | cut -f3- > output.encoded.txt
    cat output.encoded.txt | spm_decode --model preprocess/flores200_sacrebleu_tokenizer_spm.model > output.txt

    cat output.txt 
}

translate $ckp $slang $tlang $infile < /dev/stdin
