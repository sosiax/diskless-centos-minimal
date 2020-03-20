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
mkdir -p /mnt/overlay/
mkdir -p /mnt/fscache/


#======================
# look for overlay LABEL
#======================
# create a writable fs to then create our mountpoints
mount  -o user_xattr LABEL=overlay $cache_dev /mnt/overlay/ || \
  mount -t tmpfs -o size=$((`free | grep Mem | awk '{ print $2 }'`/100)) tmpfs /mnt/overlay || \
    fail "ERROR: could not create a temporary filesystem to mount the base filesystems for overlayfs"

DIRLIST="/root /var /etc"
for fs in $DIRLIST
do
  fsname=`echo $fs | tr '/' '-'`
  mkdir -p /mnt/overlay/$fs/up
  mkdir -p /mnt/overlay/$fs/work
  if [ ! -e /mnt/overlay/$fs/up/.overlay ]
  then
	rsync -a -f"+ */" -f"- *" $fs/ /mnt/overlay/$fs/ > /dev/null
	touch /mnt/overlay/$fs/up/.overlay
  fi
  mount -t overlay overlay$fsname -o lowerdir=$fs,upperdir=/mnt/overlay/$fs/up,workdir=/mnt/overlay/$fs/work $fs || fail "ERROR mounting overlay on $fs"
done

#======================
# look for fscache LABEL
#======================
mount  -o user_xattr LABEL=fscache $cache_dev /mnt/fscache/ || \
  mount -t tmpfs -o size=$((`free | grep Mem | awk '{ print $2 }'`/10)) tmpfs /mnt/fscache || \
    fail "ERROR: could not create a temporary filesystem to mount the base filesystems for overlayfs"
service cachefilesd restart 
mount -o remount /


# Check IP is 192.168.x.x
ip=`ip add | grep -ohE "192.168.([0-9]{1,3}[\.]){1}[0-9]{1,3}" | grep -v 255` || dhclient

# Lustre mount
echo "nfs-lustre.icmat.es:/mnt/lustre_fs          /LUSTRE  nfs     rw,hard,intr,rsize=8192,wsize=8192,timeo=14,nosharecache,fsc=lustre 1 1" >> /etc/fstab

mount -a

sleep 2

loadkeys es

#~ cd /
#~ tar xzf /usr/share/icmat/node-etc.tgz
#~ cd -

#~ service ganglia-gmond start
#ipa-client-install --force-join --principal admin@ICMAT.ES -w AdminIPA --unattended
