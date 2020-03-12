#!/bin/sh
SCRITP_DIR=`readlink -f $(dirname $0)`
LOG=$SCRITP_DIR/$(basename $0).log
export ROOTDISK=/var/lib/diskless/centos7-minimal/
export DISKIMAGE=/root/tmp/diskless-image/diskless.img
export VMLINUZIMAGE=$(dirname $DISKIMAGE)/vmlinuz-$(basename $DISKIMAGE)

if mount $ROOTDISK &> /dev/null 
then 
  echo "!!!! $ROOTDISK already mounted"
  read -n1 -r -p "Press any key to continue..." key
fi
mkdir -p $ROOTDISK/var/cache/yum
rsync -rAa $SCRITP_DIR/cache/yum $ROOTDISK/var/cache/yum 1> $LOG

mkdir -p $ROOTDISK

# Speed up image building -- Atention!
mount -t tmpfs -o size=4G,nr_inodes=40k tmpfs $ROOTDISK

cd $ROOTDISK
#yum group -y install --installroot=$ROOTDISK "Instalación mínima"
# install base binaries.  If you're not using puppet and IPA, this list can be trimmed.

#yum --installroot=$ROOTDISK/ --enablerepo=elrepo install basesystem filesystem bash passwd dhclient yum openssh-server openssh-clients nfs-utils ipa-client cronie-anacron selinux-policy-targeted vim-minimal kernel-lt
#yum -y install --releasever=7 --installroot=$ROOTDISK  basesystem filesystem bash passwd dhclient yum openssh-server openssh-clients nfs-utils ipa-client vim-minimal util-linux shadow-utils
echo -n "Installing system ..... "
yum -y install --releasever=/ --enablerepo=elrepo-kernel --installroot=$ROOTDISK  \
basesystem filesystem bash passwd \
dhclient openssh-server openssh-clients nfs-utils yum \
vim-minimal util-linux shadow-utils kernel-lt net-tools cronie-anacron &>> $LOG
echo "Done"

# Configuring yum 
echo "diskspacecheck=0" >> $ROOTDISK/etc/yum.conf
echo "keepcache=0" >> $ROOTDISK/etc/yum.conf

# coping script files
cp /etc/profile.d/icmat.sh $ROOTDISK/etc/profile.d/icmat.sh	
cp -f $SCRITP_DIR/rc.local $ROOTDISK/etc/rc.local
cp -f $SCRITP_DIR/chroot_cmds.sh $ROOTDISK/root/
chmod +x $ROOTDISK/root/chroot_cmds.sh 

# Adding ssh passthrought
mkdir -p $ROOTDISK/root/.ssh 
chmod 700 $ROOTDISK/root/.ssh 
cp -pr /root/.ssh/authorized_keys /root/.ssh/known_hosts $ROOTDISK/root/.ssh 

# Executing chroot commnads
chroot $ROOTDISK sh -x /root/chroot_cmds.sh 

# Getting kernel
cp $ROOTDISK/boot/vmlinuz-* $VMLINUZIMAGE
chmod 755 $VMLINUZIMAGE

##### Cleaning up
rm -fr $ROOTDISK/boot/vmlinuz-* $ROOTDISK/boot/vmlinuz-*
rm -fr $ROOTDISK/boot/vmlinuz-* $ROOTDISK/boot/init*
# Atention !!!
rm -fr $ROOTDISK/usr/lib/firmware
rm -fr $ROOTDISK/usr/share/man/
rm -fr $ROOTDISK/usr/share/doc

# Keeping cache files
mkdir -p $SCRITP_DIR/cache/yum
rsync -rAav $ROOTDISK/var/cache/yum $SCRITP_DIR/cache/yum 1>> $LOG
rm -fr $ROOTDISK/var/cache/yum $ROOTDISK/var/lib/yum/*



read -n1 -r -p "Press any key to continue..." key

cd $ROOTDISK 
find | cpio -oc | gzip -9 > $DISKIMAGE 2>> $LOG
chmod 644 $DISKIMAGE


