#!/bin/bash

set -e

# Directory we're compressing
COMPRESS_DIR_PATH=${COMPRESS_DIR_PATH:-"/compress"}

# Temporary directory used when there is not enough space in $COMPRESS_DIR_PATH
COMPRESS_TMP_DIR_PATH=${COMPRESS_TMP_DIR_PATH:-"/compress_tmp"}

# Output zip file name
OUTPUT_ZIP_NAME=${OUTPUT_ZIP_FILE_NAME:-"all.zip"}

function compressBatch {
    for file in $@; do

        # Check if file is a directory
        if [ -d $file ]; then
            compress $file
            continue
        fi

        if [[ "$file" == "$COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME" ]]; then
            echo "Skipping: $1"
            continue
        fi

        # Check if there's enough space in $COMPRESS_DIR_PATH
        uncompressed_size=$(du -s $file | awk '{print $1}')
        space_left=$(df $COMPRESS_DIR_PATH | tail -1 | awk '{print $4}')

        # try compression in the $COMPRESS_DIR_PATH directory
        if [ "$space_left" -ge $uncompressed_size ]; then
            #echo "$file size: $uncompressed_size  < than $space_left. Adding directly to $COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME"

            #compress $file $COMPRESS_DIR_PATH

            continue
        fi

        # try compression in the $COMPRESS_TMP_DIR_PATH directory
        space_left_tmp=$(df $COMPRESS_TMP_DIR_PATH | tail -1 | awk '{print $4}')
        if [ "$space_left_tmp" -ge $uncompressed_size ]; then
            echo "Not enough space in the \"$COMPRESS_DIR_PATH\" directory. Using \"$COMPRESS_TMP_DIR_PATH\" directory to compress \"$file\" file"

            echo "mkdir -p \"${COMPRESS_TMP_DIR_PATH}$(dirname ${file})\""
            mkdir -p "${COMPRESS_TMP_DIR_PATH}$(dirname ${file})"

            echo "cp -p --parents \"${file}\" \"${COMPRESS_TMP_DIR_PATH}\""
            cp -p --parents "${file}" "${COMPRESS_TMP_DIR_PATH}"
            rm "${file}"

            compress "$COMPRESS_TMP_DIR_PATH/$file" $COMPRESS_TMP_DIR_PATH$COMPRESS_DIR_PATH

            continue
        fi
    done
}

function compress {
    file_path="$1"
    top_dir="$2"

    # extract the top directory and store it in a variable
    # top_dir=$(echo $file_path | awk -F/ '{print FS $2}')
    
    relative_path=${file_path:${#top_dir}+1}
    
    echo "cd $top_dir && zip -uXo $COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME \"$relative_path\""

    # Add file to the zip archive
    cd $top_dir && zip -uXo $COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME "$relative_path"

    # Remove file after compression
    rm $file_path
}

# Remove tailing slashes unless root dir
if [[ "$COMPRESS_DIR_PATH" != "/" ]]; then
        COMPRESS_DIR_PATH=${COMPRESS_DIR_PATH%/}
fi
COMPRESS_TMP_DIR_PATH=${COMPRESS_TMP_DIR_PATH%/}


if [ "$(ls -A $COMPRESS_TMP_DIR_PATH)" ]; then
    echo "$COMPRESS_TMP_DIR_PATH is not empty, exiting with error."
    exit 1
fi


# Setup temporary compression directory
if [ ! -d $COMPRESS_TMP_DIR_PATH ]
then
    echo "Creating $COMPRESS_TMP_DIR_PATH directory"
    mkdir $COMPRESS_TMP_DIR_PATH
fi

files=$(find $COMPRESS_DIR_PATH -type f ! -size 0 -printf '%s %p\n' | sort -n -r | awk '{print $2}')

compressBatch $files

#echo -e "$files"
