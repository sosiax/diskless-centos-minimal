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

dhclient

#TODO : check for cache device 
echo "nfs-lustre.icmat.es:/mnt/lustre_fs          /LUSTRE  nfs     rw,hard,intr,rsize=8192,wsize=8192,timeo=14,nosharecache,fsc=lustre 1 1" >> /etc/fstab
echo "192.168.1.133:/var/lib/diskless/centos7/usr /usr     nfs     ro,hard,intr,rsize=8192,wsize=8192,timeo=14,nosharecache,fsc=usr    1 1" >> /etc/fstab

mount -a

sleep 2

loadkeys es

#~ cd /
#~ tar xzf /usr/share/icmat/node-etc.tgz
#~ cd -

#~ service ganglia-gmond start
#ipa-client-install --force-join --principal admin@ICMAT.ES -w AdminIPA --unattended
