#dd if=/dev/zero of=limited_dir.img bs=10M count=1
#mkfs.ext4 limited_dir.img
#mount -o loop,rw,suid,dev limited_dir.img /mnt/limited_dir

dd if=/dev/zero of=/mnt/limited_dir/file1.txt bs=2M count=1
dd if=/dev/zero of=/mnt/limited_dir/file2.txt bs=2M count=1
dd if=/dev/zero of=/mnt/limited_dir/file3.txt bs=2M count=1
