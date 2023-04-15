#!/bin/bash

set -e

# Directory we're compressing
COMPRESS_DIR_PATH=${COMPRESS_DIR_PATH:-"/compress"}

# Temporary directory used when there is not enough space in $COMPRESS_DIR_PATH
COMPRESS_TMP_DIR_PATH=${COMPRESS_TMP_DIR_PATH:-"/tmp/compress_tmp"}

# Output zip file name
OUTPUT_ZIP_NAME=${OUTPUT_ZIP_FILE_NAME:-"all.zip"}

function compressBatch {
    for file in $@; do

        echo -e "----------------------------------------"

        if [ "$file" == "$COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME" ] || [ "$file" == "$COMPRESS_DIR_PATH" ]; then
            echo "Skipping: $1 $COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME $COMPRESS_DIR_PATH"
            continue
        fi

        #Check if file is a directory
        if [ -d $file ]; then
            echo -e "compressBatch() \t adding $file directory to the archive"

            compress $file $COMPRESS_DIR_PATH
            continue
        fi

        # Check if there's enough space in $COMPRESS_DIR_PATH
        uncompressed_size=$(du -s "$file" | awk '{print $1}')
        space_left=$(df "$COMPRESS_DIR_PATH" | tail -1 | awk '{print $4}')

        # try compression in the $COMPRESS_DIR_PATH directory
        if [ "$space_left" -ge $uncompressed_size ]; then
            echo -e "compressBatch() \tDirect compression $file size: $uncompressed_size < $space_left"

            compress $file $COMPRESS_DIR_PATH

            continue
        fi

        # try compression in the $COMPRESS_TMP_DIR_PATH directory
        space_left_tmp=$(df $COMPRESS_TMP_DIR_PATH | tail -1 | awk '{print $4}')
        if [ "$space_left_tmp" -ge $uncompressed_size ]; then
            echo -e "compressBatch() \tNot enough space in the \"$COMPRESS_DIR_PATH\" directory. Using \"$COMPRESS_TMP_DIR_PATH\" directory to compress \"$file\" file"

            echo -e "compressBatch() \tmkdir -p \"${COMPRESS_TMP_DIR_PATH}$(dirname ${file})\""
            mkdir -p "${COMPRESS_TMP_DIR_PATH}$(dirname ${file})"

            echo -e "compressBatch() \tcp -preserve --parents \"${file}\" \"${COMPRESS_TMP_DIR_PATH}\""
            cp --preserve --parents "${file}" "${COMPRESS_TMP_DIR_PATH}"

			# recreate file and folder permissions in the temporary directory
			file_dirname=$(dirname "$file")
			file_name=$(basename "$file")

			# temporary folders and file that should be removed
			IFS="/" read -ra directories_list <<< "$file"

			chown_reference=""
			chown_destination=$COMPRESS_TMP_DIR_PATH

			for ((i=1; i<${#directories_list[@]}-1; i++)); do
				chown_reference+="/${directories_list[$i]}"
				chown_destination+="/${directories_list[$i]}"

				if [[ ${#chown_reference} -gt ${#COMPRESS_DIR_PATH} ]]; then
                    echo -e "compressBatch() \tchown --reference=\"$chown_reference\" \"$chown_destination\""
					chown --reference="$chown_reference" "$chown_destination"

					echo -e "compressBatch() \tchmod --reference=\"$chown_reference\" \"$chown_destination\""
					chmod --reference="$chown_reference" "$chown_destination"
				fi
			done

            # remove the original file that was moved to the tmp directory
            rm -rf "${file}"

            compress "$COMPRESS_TMP_DIR_PATH$file" "$COMPRESS_TMP_DIR_PATH$COMPRESS_DIR_PATH"

            # remove temporary directories if they were created
            echo -e "compressBatch() \trm -rf $COMPRESS_TMP_DIR_PATH/*"
            rm -rf $COMPRESS_TMP_DIR_PATH/*

            continue
        fi
    done
}

function compress {

    file_path="$1"
    top_dir="$2"

    echo -e "#COMPRESS:\t$file_path $top_dir"

    relative_path=${file_path:${#top_dir}+1}
    
    # This solves a problem with ownerhship when compressing
    # a deeply nested file within folders. Parent folders
    # didin't have the proper permissions
    IFS="/" read -ra directories_list <<< "$file_path"

    file_dir=""

    for ((i=1; i<${#directories_list[@]}-1; i++)); do
        file_dir+="/${directories_list[$i]}"

        if [[ ${#file_dir} -gt ${#top_dir} ]]; then
            folder_relative_path=${file_dir:${#top_dir}+1}
            echo -e "compress() DIR: \tcd \"$top_dir\" && zip \"$COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME\" \"$folder_relative_path\""
            cd "$top_dir" && zip "$COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME" "$folder_relative_path"
        fi
    done

    echo -e "compress() ADD: \tcd \"$top_dir\" && zip \"$COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME\" \"$relative_path\""

    # Add file/directory to the zip archive
    cd "$top_dir" && zip "$COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME" "$relative_path"

    # Remove file / directory after compression
    rm -rf $file_path
}

######################
### VALIDATE

if [[ $EUID > 0 ]]; then
  echo "Please run as root/sudo"
  exit 1
fi

# Remove tailing slashes unless root dir
if [[ "$COMPRESS_DIR_PATH" != "/" ]]; then
        COMPRESS_DIR_PATH=${COMPRESS_DIR_PATH%/}
fi
COMPRESS_TMP_DIR_PATH=${COMPRESS_TMP_DIR_PATH%/}


if [ "$(ls -A $COMPRESS_TMP_DIR_PATH)" ]; then
    echo "$COMPRESS_TMP_DIR_PATH is not empty, exiting with error."
    exit 1
fi

# check if temporary and compression paths are different
if [[ "$COMPRESS_DIR_PATH" == "$COMPRESS_TMP_DIR_PATH" ]]; then
    echo "Compression and temporary paths must be different"
    exit 1
fi

# Setup temporary compression directory
if [ ! -d $COMPRESS_TMP_DIR_PATH ]
then
    echo "Creating $COMPRESS_TMP_DIR_PATH directory"
    mkdir $COMPRESS_TMP_DIR_PATH
fi

### VALIDATE
######################

files=$(find "$COMPRESS_DIR_PATH" -type f ! -size 0 -printf '%s %p\n' | sort -n -r | awk '{print $2}')
compressBatch $files

files_and_directories=$(find "$COMPRESS_DIR_PATH" -printf '%d %p\n' | sort -n -r | awk '{print $2}')
compressBatch $files_and_directories

#echo -e "$files"
