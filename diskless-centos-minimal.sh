#!/bin/sh
SCRITP_DIR=`readlink -f $(dirname $0)`
export ROOTDISK=/var/lib/diskless/centos7-minimal/
export DISKIMAGE=/root/tmp/diskless-image/diskless.img
export VMLINUZIMAGE=$(dirname $DISKIMAGE)/vmlinuz-$(basename $DISKIMAGE)

if mount $ROOTDISK &> /dev/null 
then 
  echo "!!!! $ROOTDISK already mounted"
  read -n1 -r -p "Press any key to continue..." key
fi

mkdir -p $ROOTDISK

# Speed up image building -- Atention!
mount -t tmpfs -o size=4G,nr_inodes=40k tmpfs $ROOTDISK

cd $ROOTDISK
#yum group -y install --installroot=$ROOTDISK "Instalación mínima"
# install base binaries.  If you're not using puppet and IPA, this list can be trimmed.

#yum --installroot=$ROOTDISK/ --enablerepo=elrepo install basesystem filesystem bash passwd dhclient yum openssh-server openssh-clients nfs-utils ipa-client cronie-anacron selinux-policy-targeted vim-minimal kernel-lt
#yum -y install --releasever=7 --installroot=$ROOTDISK  basesystem filesystem bash passwd dhclient yum openssh-server openssh-clients nfs-utils ipa-client vim-minimal util-linux shadow-utils
yum -y install --releasever=7 --enablerepo=elrepo-kernel --installroot=$ROOTDISK  basesystem filesystem bash passwd dhclient openssh-server openssh-clients nfs-utils vim-minimal util-linux shadow-utils kernel-lt net-tools

# Configuring yum 
echo "diskspacecheck=0" >> $ROOTDISK/etc/yum.conf
echo "keepcache=0" >> $ROOTDISK/etc/yum.conf

cp /etc/profile.d/icmat.sh $ROOTDISK/etc/profile.d/icmat.sh	

#Installing kernel-lt
#read -n1 -r -p "Press any key to continue..." key
#cp /etc/yum.repos.d/elrepo.repo $ROOTDISK/etc/yum.repos.d/elrepo.repo
# Coping rc.local
cp -f $SCRITP_DIR/rc.local $ROOTDISK/rc.local
mkdir $ROOTDISK/root/.ssh 
chmod 700 $ROOTDISK/root/.ssh 
cp -pr /root/.ssh/authorized_keys /root/.ssh/known_hosts $ROOTDISK/root/.ssh 

read -n1 -r -p "Press any key to continue..." key
#yum -y install kernel-lt --enablerepo=elrepo-kernel --releasever=7 --installroot=$ROOTDISK


# Set the root password in the image
echo "root:2dminHPC19" | chroot $ROOTDISK chpasswd

cd $ROOTDISK
ln -s ./sbin/init ./init
cd - 

# Updating fstab - TODO : check for cache device 
echo "192.168.1.133:/var/lib/diskless/centos7/usr        /usr                 nfs     ro,hard,intr,rsize=8192,wsize=8192,timeo=14,nosharecache,fsc 1 1" >> $ROOTDISK/etc/fstab
echo "nfs-lustre.icmat.es:/mnt/lustre_fs        /LUSTRE                 nfs     rw,hard,intr,rsize=8192,wsize=8192,timeo=14,nosharecache,fsc 1 1" >> $ROOTDISK/etc/fstab

# Enable networking
echo "NETWORKING=yes" > $ROOTDISK/etc/sysconfig/network
chmod 644 $ROOTDISK/etc/sysconfig/network


# Getting kernel
cp $ROOTDISK/boot/vmlinuz-* $VMLINUZIMAGE
chmod 755 $VMLINUZIMAGE

# Cleaning up
rm -fr $ROOTDISK/boot/vmlinuz-* $ROOTDISK/boot/vmlinuz-*
rm -fr $ROOTDISK/var/cache/yum $ROOTDISK/var/lib/yum/*
rm -fr $ROOTDISK/boot/vmlinuz-* $ROOTDISK/boot/init*

cd $ROOTDISK
find | cpio -ocv | gzip -9 > $DISKIMAGE
chmod 644 $DISKIMAGE


