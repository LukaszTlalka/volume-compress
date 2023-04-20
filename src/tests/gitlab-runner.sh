#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

set -e

mkdir /mnt/limited_dir_5M/


mkdir           /mnt/limited_dir_5M/empty-dir
chown 1235:1235 /mnt/limited_dir_5M/empty-dir/

mkdir           /mnt/limited_dir_5M/lvl1
chown 1234:1234 /mnt/limited_dir_5M/lvl1/

mkdir           /mnt/limited_dir_5M/lvl1/empty-dir
chown 1236:1236 /mnt/limited_dir_5M/lvl1/empty-dir/


mkdir           /mnt/limited_dir_5M/lvl1/lvl2
chown 1234:1234 /mnt/limited_dir_5M/lvl1/lvl2

mkdir           "/mnt/limited_dir_5M/lvl1/lvl2/lvl3 with spaces "
chown 1234:1234 "/mnt/limited_dir_5M/lvl1/lvl2/lvl3 with spaces "
chmod 422       "/mnt/limited_dir_5M/lvl1/lvl2/lvl3 with spaces "

dd if=/dev/zero of="/mnt/limited_dir_5M/lvl1/lvl2/lvl3 with spaces /file1 with spaces .txt" bs=2M count=1
dd if=/dev/zero of=/mnt/limited_dir_5M/lvl1/lvl2/file2.txt bs=2M count=1

touch "/mnt/limited_dir_5M/lvl1/empty file1.txt"
touch /mnt/limited_dir_5M/lvl1/empty-file2.txt
touch /mnt/limited_dir_5M/lvl1/empty-file3.txt

chmod 777 "/mnt/limited_dir_5M/lvl1/lvl2/lvl3 with spaces /file1 with spaces .txt"
chmod 744 /mnt/limited_dir_5M/lvl1/lvl2/file2.txt 



#################################################
### /compress directory full but enough spacie to use temp directory


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
