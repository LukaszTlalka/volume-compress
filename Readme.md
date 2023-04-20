# Volume Compress  

This project is designed to compress files within a specified directory and remove them afterward. If there is insufficient space in the original directory, a temporary directory is used instead. Additionally, if there is not enough space in the temporary directory, the script can utilize a RAM drive for compression purposes. In situations where all inodes are used up, temporary files can be stored on a temporary or RAM drive to enable file compression.


## Usage  

The project is designed to be executed using docker:

```
docker run -ti --rm -v "./data:/compress" lukasztlalka/volume-compress:latest
```

- `data`: directory you want to compress and delete the files from


To extract the data run:

```
unzip -X all.zip
```
___

The script can also be run with the following command:

```
./src/main.sh
```

## Environment Variables

The following environment variables can be set to customize the behavior of the `volume-compress` script:


- `__VERBOSE`: verbose level 0=error 1=warning 2=info 3=debug
- `COMPRESS_DIR_PATH`: This variable specifies the directory path of the input directory that needs to be compressed. By default, it is set to `/compress`.
- `COMPRESS_TMP_DIR_PATH`: This variable specifies the temporary directory path where intermediate compressed files will be stored. By default, it is set to `/tmp/compress_tmp` directory in the current working directory.
- `SKIP_TEMP_EMPTY_CHECK`: This variable is a boolean value (true/false) that determines whether or not to skip the check for empty temporary files. By default, it is set to false.
- `RAM_TMP_DIR_PATH`: This variable specifies the temporary directory path where temporary files will be stored when the in-memory compression is used. By default, it is set to `/dev/shm`.
- `OUTPUT_ZIP_NAME`: This variable specifies the name of the output ZIP file that will be generated. By default, it is set to `all.zip`.

Note that all of these environment variables are optional. If you don't specify them, the default values will be used. However, you can override them as needed to customize the behavior of the script.

## Requirements  

This script is designed to run on `alpine:latest` image with zip, bash, and findutils installed.

# Disclaimer

Please note that this project is provided as-is and without any warranty or guarantee of any kind, either express or implied. The use of this project is at your own risk. I will not be responsible for any loss or damage that may arise from the use of this project, including but not limited to data loss or errors.

It is important that you review and understand the code before using it, and that you test it thoroughly in a non-production environment before using it in a production environment. If you encounter any issues or errors while using this project, please report them on the project's GitHub page, and I will do my best to address them in a timely manner.

# License
This script is licensed under the MIT License.
