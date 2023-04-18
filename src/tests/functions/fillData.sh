#!/bin/bash

function fillData {
    umount /mnt/limited_dir_5M 2> /dev/null || true
    umount /mnt/limited_dir_1M 2> /dev/null || true
    umount /mnt/limited_dir_5M_NO_INODES 2> /dev/null || true

    rm /tmp/limited_dir_5M.img 2> /dev/null || true
    rm /tmp/limited_dir_1M.img 2> /dev/null || true
    rm /tmp/limited_dir_5M_NO_INODES.img 2> /dev/null || true

    mkdir /mnt/limited_dir_5M_NO_INODES/ 2> /dev/null || true
    rm -rf /mnt/limited_dir_5M_NO_INODES/* 2> /dev/null || true

    mkdir /mnt/limited_dir_1M/ 2> /dev/null || true
    rm -rf /mnt/limited_dir_1M/* 2> /dev/null || true

    mkdir /mnt/limited_dir_5M/ 2> /dev/null || true
    rm -rf /mnt/limited_dir_5M/* 2> /dev/null || true

    mkdir /tmp/limited_dir_5M_output 2> /dev/null || true
    rm -rf /tmp/limited_dir_5M_output/* 2> /dev/null || true

    mkdir /tmp/limited_dir_5M_clone 2> /dev/null || true
    rm -rf /tmp/limited_dir_5M_clone/* 2> /dev/null || true

    dd if=/dev/zero of=/tmp/limited_dir_5M.img bs=5M count=1
    mkfs.ext4 -N 50 /tmp/limited_dir_5M.img
    mount -o loop,rw,suid,dev /tmp/limited_dir_5M.img /mnt/limited_dir_5M

    # fill up space on the temp directory
    dd if=/dev/zero of=/tmp/limited_dir_1M.img bs=1M count=1
    mkfs.ext4 -N 50 /tmp/limited_dir_1M.img
    mount -o loop,rw,suid,dev /tmp/limited_dir_1M.img /mnt/limited_dir_1M

    # no inodes
    dd if=/dev/zero of=/tmp/limited_dir_5M_NO_INODES.img bs=5M count=1
    mkfs.ext4 -N 5 /tmp/limited_dir_5M_NO_INODES.img
    mount -o loop,rw,suid,dev /tmp/limited_dir_5M_NO_INODES.img /mnt/limited_dir_5M_NO_INODES

    rm -rf /mnt/limited_dir_1M/*
    rm -rf /mnt/limited_dir_5M/*
    rm -rf /mnt/limited_dir_5M_NO_INODES/*

    mkdir           /mnt/limited_dir_5M/empty-dir
    chown 1235:1235 /mnt/limited_dir_5M/empty-dir/

    mkdir           /mnt/limited_dir_5M/lvl1
    chown 1234:1234 /mnt/limited_dir_5M/lvl1/

    mkdir           /mnt/limited_dir_5M/lvl1/empty-dir
    chown 1236:1236 /mnt/limited_dir_5M/lvl1/empty-dir/


    mkdir           /mnt/limited_dir_5M/lvl1/lvl2
    chown 1234:1234 /mnt/limited_dir_5M/lvl1/lvl2

    mkdir           /mnt/limited_dir_5M/lvl1/lvl2/lvl3
    chown 1234:1234 /mnt/limited_dir_5M/lvl1/lvl2/lvl3
    chmod 422       /mnt/limited_dir_5M/lvl1/lvl2/lvl3

    dd if=/dev/zero of=/mnt/limited_dir_5M/lvl1/lvl2/lvl3/file1.txt bs=2M count=1
    dd if=/dev/zero of=/mnt/limited_dir_5M/lvl1/lvl2/file2.txt bs=2M count=1

    touch /mnt/limited_dir_5M/lvl1/empty-file1.txt
    touch /mnt/limited_dir_5M/lvl1/empty-file2.txt
    touch /mnt/limited_dir_5M/lvl1/empty-file3.txt

    chmod 777 /mnt/limited_dir_5M/lvl1/lvl2/lvl3/file1.txt 
    chmod 744 /mnt/limited_dir_5M/lvl1/lvl2/file2.txt 

    ## create the rest of files to fill in all inodes
    mkdir /mnt/limited_dir_5M/inodes-fill/
    for i in {0..42}; do
        touch "/mnt/limited_dir_5M/inodes-fill/file$i"
    done

    touch /mnt/limited_dir_5M_NO_INODES/.test1
    touch /mnt/limited_dir_5M_NO_INODES/.test2
    touch /mnt/limited_dir_5M_NO_INODES/.test3
    touch /mnt/limited_dir_5M_NO_INODES/.test4
    touch /mnt/limited_dir_5M_NO_INODES/.test5
    touch /mnt/limited_dir_5M_NO_INODES/.test6
}
