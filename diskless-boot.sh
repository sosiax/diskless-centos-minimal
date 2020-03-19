#!/bin/bash
# THIS FILE IS ADDED FOR COMPATIBILITY PURPOSES
#
# It is highly advisable to create own systemd services or udev rules
# to run scripts during boot instead of using this file.
#
# In contrast to previous versions due to parallel execution during boot
# this script will NOT be run after all other services.
#
# Please note that you must run 'chmod +x /etc/rc.d/rc.local' to ensure
# that this script will be executed during boot.

touch /var/lock/subsys/diskless-boot

fail(){
	echo -e "$1"
	exit 1
}

# load module
modprobe overlay || fail "ERROR: missing overlay kernel module"

# create a writable fs to then create our mountpoints
mount -t tmpfs tmpfs /mnt || fail "ERROR: could not create a temporary filesystem to mount the base filesystems for overlayfs"
mkdir -p /mnt/cache/

#look for fscache LABEL
cache_dev=`blkid -L fscache`
if [ -z $cache_dev ]
then 
	# create a writable fs to then create our mountpoints
	mount  -o user_xattr $cache_dev /mnt/cache/ || fail "ERROR: could not create a temporary filesystem to mount the base filesystems for overlayfs"
	mkdir -p /mnt/cache/fscache
	service cachefilesd restart 
fi


DIRLIST="/root /var /etc"
for fs in $DIRLIST
do
  fsname=`echo $fs | tr '/' '-'`
  mkdir -p /mnt/cache/overlay/$fs/up
  mkdir -p /mnt/cache/overlay/$fs/work
  mount -t overlay overlay$fsname -o lowerdir=$fs,upperdir=/mnt/cache/overlay/$fs/up,workdir=/mnt/cache/overlay/$fs/work $fs
done

#Check IP
ip=`ip add | grep -ohE "192.168.([0-9]{1,3}[\.]){1}[0-9]{1,3}" | grep -v 255` || dhclient

#TODO : check for cache device 
echo "nfs-lustre.icmat.es:/mnt/lustre_fs          /LUSTRE  nfs     rw,hard,intr,rsize=8192,wsize=8192,timeo=14,nosharecache,fsc=lustre 1 1" >> /etc/fstab
#echo "192.168.1.133:/var/lib/diskless/centos7/usr /usr     nfs     ro,hard,intr,rsize=8192,wsize=8192,timeo=14,nosharecache,fsc=usr    1 1" >> /etc/fstab

mount -a

sleep 2

loadkeys es

#~ cd /
#~ tar xzf /usr/share/icmat/node-etc.tgz
#~ cd -

#~ service ganglia-gmond start
#ipa-client-install --force-join --principal admin@ICMAT.ES -w AdminIPA --unattended
