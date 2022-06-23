#!/bin/bash
#
# Repackages GBIF backbone https://hosted-datasets.gbif.org/datasets/backbone
# into data products optimized for index building. 
# Repackage process currently includes creating various reverse sorted, 
# trimmed, versions of GBIF's Simplified Backbone.
#
# Note that GNU's sort ignores whitespaces when sorting using some locale.
# To include whitespaces in the sorting of names, ```LC_ALL=C sort -r```
# was used as suggested in 
# https://stackoverflow.com/questions/2691821/unexpected-result-from-gnu-sort .
#
# Example usage:
#
# ./repackage-gbif-backbone.sh 
#
# With results will be placed in the "target" directory:
# target/
#   README
#   gbif-backbone-simple.txt.gz (downloaded original)
#   gbif-backbone-by-id.tsv.gz  (repackaged)
#   gbif-backbone-by-name.tsv.gz (repackaged)
#   ...
#
set -xe

mkdir -p target

# apply date stamp
cat <(echo -e "Publication date:\n$(date -Iseconds)\n\n") <(cat static/README)\
> target/README

# copy this script
cp "$0" target/

curl https://hosted-datasets.gbif.org/datasets/backbone/backbone-current-simple.txt.gz\
> target/backbone-current-simple.txt.gz

cat target/backbone-current-simple.txt.gz\
| gunzip\
| tr '\r' '\n'\
| cut -f1-20\
| LC_ALL=C sort -nr\
| gzip\
| tee target/gbif-backbone-by-id.tsv.gz\
| gunzip\
| cut -f1,20\
| awk -F '\t' '{ print $2 "\t" $1 }'\
| LC_ALL=C sort -r\
| gzip\
 1> target/gbif-backbone-by-name.tsv.gz

calc_hash() {
  sha256sum - | grep -o "[a-f0-9]*"
}

document_hash_gz () {
    document_hash "$1.gz"
    local HASH=$(cat "target/$1.gz" | gunzip | calc_hash)
    echo $HASH > target/$1.sha256
    echo -e "    hash://sha256/$HASH (uncompressed)\n" >> target/README
}

document_hash () {
    local HASH=$(cat "target/$1" | calc_hash)
    echo $HASH > target/$1.sha256
    echo -e "$1:\n    hash://sha256/$HASH\n" >> target/README
}

document_hash repackage-gbif-backbone.sh
document_hash_gz gbif-backbone-simple.txt
document_hash_gz gbif-backbone-by-name.tsv
document_hash_gz gbif-backbone-by-id.tsv
