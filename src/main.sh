#!/bin/bash

set -e

# Directory we're compressing
COMPRESS_DIR_PATH=${COMPRESS_DIR_PATH:-"/compress"}
COMPRESS_DIR_FREE_INODES=$(df -iP "$COMPRESS_DIR_PATH" | awk 'NR==2 {print $4}')

# Temporary directory used when there is not enough space in $COMPRESS_DIR_PATH
COMPRESS_TMP_DIR_PATH=${COMPRESS_TMP_DIR_PATH:-"/tmp/compress_tmp"}
COMPRESS_TMP_DIR_FREE_INODES=$(df -iP "$COMPRESS_TMP_DIR_PATH" | awk 'NR==2 {print $4}')


# Check if the temporary directory is empty
SKIP_TEMP_EMPTY_CHECK=${SKIP_TEMP_EMPTY_CHECK:-false}

COMPRESS_TMP_FREE_INODES=$(df -iP "$COMPRESS_TMP_DIR_PATH" | awk 'NR==2 {print $4}')

# Temporary RAM directory used when there is not enough space in $COMPRESS_TMP_DIR_PATH
RAM_TMP_DIR_PATH=${RAM_TMP_DIR_PATH:-"/mnt/ram"}
RAM_MEMORY_USAGE=${RAM_MEMORY_USAGE:-"50G"}

# Output zip file name
OUTPUT_ZIP_NAME=${OUTPUT_ZIP_FILE_NAME:-"all.zip"}

function mountRamVolume {
    if [ -z "${ram_already_mounted+x}" ]; then
        ram_already_mounted=true
        echo -e "compressBatch() \tmount -t tmpfs -o size=$RAM_MEMORY_USAGE tmpfs \"$RAM_TMP_DIR_PATH\""
        mount -t tmpfs -o size=$RAM_MEMORY_USAGE tmpfs "$RAM_TMP_DIR_PATH"
    fi
}

function moveFileToTemp {
    file="$1"
    tmp_directory="$2"

    echo -e "moveFileToTemp() \tNot enough space in the \"$COMPRESS_DIR_PATH\" directory. Using \"$tmp_directory\" directory to compress \"$file\" file"
    echo -e "moveFileToTemp() \tmkdir -p \"${tmp_directory}$(dirname ${file})\""
    mkdir -p "${tmp_directory}$(dirname ${file})"

    echo -e "moveFileToTemp() \tcp -preserve --parents \"${file}\" \"${tmp_directory}\""
    cp --preserve --parents "${file}" "${tmp_directory}"

    # recreate file and folder permissions in the temporary directory
    file_dirname=$(dirname "$file")
    file_name=$(basename "$file")

    # temporary folders and file that should be removed
    IFS="/" read -ra directories_list <<< "$file"

    chown_reference=""
    chown_destination=$tmp_directory

    for ((i=1; i<${#directories_list[@]}-1; i++)); do
        chown_reference+="/${directories_list[$i]}"
        chown_destination+="/${directories_list[$i]}"

        if [[ ${#chown_reference} -gt ${#COMPRESS_DIR_PATH} ]]; then
            echo -e "moveFileToTemp() \tchown --reference=\"$chown_reference\" \"$chown_destination\""
            chown --reference="$chown_reference" "$chown_destination"

            echo -e "moveFileToTemp() \tchmod --reference=\"$chown_reference\" \"$chown_destination\""
            chmod --reference="$chown_reference" "$chown_destination"
        fi
    done

    # remove the original file that was moved to the tmp directory
    rm -f "${file}"

    compress "$tmp_directory$file" "$tmp_directory$COMPRESS_DIR_PATH"

    # remove temporary directories if they were created
    echo -e "moveFileToTemp() \trm -rf $tmp_directory/*"
    rm -rf $tmp_directory/*
}

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

        echo "space left TMP: $space_left_tmp"
        if [ "$space_left_tmp" -ge $uncompressed_size ] && [[ $COMPRESS_DIR_FREE_INODES -gt 5 ]]; then
            moveFileToTemp $file $COMPRESS_TMP_DIR_PATH
            continue
        fi


        # try compression in the $RAM_TMP_DIR_PATH directory
        mountRamVolume

        # try compression in the $COMPRESS_TMP_DIR_PATH directory
        space_left_tmp=$(df $RAM_TMP_DIR_PATH | tail -1 | awk '{print $4}')
        if [ "$space_left_tmp" -ge $uncompressed_size ]; then
            moveFileToTemp $file $RAM_TMP_DIR_PATH
            continue
        fi

        echo "$file (${uncompressed_size}b) cannot be compressed. Not ehough space left in the ${COMPRESS_DIR_PATH} directory, $COMPRESS_TMP_DIR_PATH and RAM drive"
        exit 1

    done
}

function compress {

    file_path="$1"
    top_dir="$2"

    echo -e "#COMPRESS:\t$file_path $top_dir"

    # if number of inodes has been reached on the compress directory we will use RAM drive as temporary directory for zip
       
    zip_temp_directory_parameter="" 
    if [[ $COMPRESS_DIR_FREE_INODES -lt 3 ]]; then
        ((COMPRESS_DIR_FREE_INODES+=1))

        mountRamVolume

        mkdir "$RAM_TMP_DIR_PATH/.volume-compress-ram-drive" 2> /dev/null || true 
        echo -e "compress() ADD: \tmkdir \"$RAM_TMP_DIR_PATH/.volume-compress-ram-drive\""
        zip_temp_directory_parameter=" -b $RAM_TMP_DIR_PATH/.volume-compress-ram-drive "
    fi

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
            echo -e "compress() DIR: \tcd \"$top_dir\" && zip $zip_temp_directory_parameter \"$COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME\" \"$folder_relative_path\""
            cd "$top_dir" && zip $zip_temp_directory_parameter "$COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME" "$folder_relative_path"
        fi
    done

    echo -e "compress() ADD: \tcd \"$top_dir\" && zip $zip_temp_directory_parameter  \"$COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME\" \"$relative_path\""
    # Add file/directory to the zip archive
    cd "$top_dir" && zip $zip_temp_directory_parameter  "$COMPRESS_DIR_PATH/$OUTPUT_ZIP_NAME" "$relative_path"

    # Remove file / directory after compression
    rm -rf $file_path
}

######################
### VALIDATE

if [[ $EUID > 0 ]]; then
  echo "Please run as root/sudo"
  exit 1
fi

# Unmount ram drive if mounted
umount "$RAM_TMP_DIR_PATH" 2> /dev/null || true

# Remove tailing slashes unless root dir
if [[ "$COMPRESS_DIR_PATH" != "/" ]]; then
        COMPRESS_DIR_PATH=${COMPRESS_DIR_PATH%/}
fi
COMPRESS_TMP_DIR_PATH=${COMPRESS_TMP_DIR_PATH%/}
RAM_TMP_DIR_PATH=${RAM_TMP_DIR_PATH%/}

if [ "$(ls -A $RAM_TMP_DIR_PATH)" ]; then
    echo "$RAM_TMP_DIR_PATH is not empty, exiting with error."
    exit 1
fi

if [ "$SKIP_TEMP_EMPTY_CHECK" != true ] && [ "$(ls -A "$COMPRESS_TMP_DIR_PATH")" ]; then
    echo "$COMPRESS_TMP_DIR_PATH is not empty, exiting with error."
    exit 1
fi

# check if temporary and compression paths are different
if [[ "$COMPRESS_DIR_PATH" == "$COMPRESS_TMP_DIR_PATH" ]]; then
    echo "Compression and temporary paths must be different"
    exit 1
fi


# Setup temporary compression directories
if [ ! -d $RAM_TMP_DIR_PATH ]
then
    echo "Creating $RAM_TMP_DIR_PATH directory"
    mkdir $RAM_TMP_DIR_PATH
fi

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
