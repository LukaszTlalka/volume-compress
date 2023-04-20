#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

set -e

source ./functions/fillData.sh

#################################################
### /compress directory full but enough spacie to use temp directory

fillData 

# copy all files to a separate directory
cp -rp /mnt/limited_dir_5M/. /tmp/limited_dir_5M_clone/
cp -rp /mnt/limited_dir_5M/. /tmp/limited_dir_5M_clone/

COMPRESS_TMP_DIR_PATH=/tmp/limited_dir_5M/ COMPRESS_DIR_PATH=/mnt/limited_dir_5M/ $SCRIPT_DIR/../main.sh

unzip -X /mnt/limited_dir_5M/all.zip -d /tmp/limited_dir_5M_output/

clone_data=$(ls --recursive -al /tmp/limited_dir_5M_clone/ | sed -e "s#/tmp/limited_dir_5M_clone/##g")
output_data=$(ls --recursive -al /tmp/limited_dir_5M_output/ | sed -e "s#/tmp/limited_dir_5M_output/##g")

echo -e "$clone_data" > /tmp/original2
echo -e "$output_data" > /tmp/extracted2

if [[ "$clone_data" != "$output_data" ]]; then
    echo "Compressed and extracted data differ"
    exit 1
fi

echo -e "\e[32mSuccess!\e[0m"
