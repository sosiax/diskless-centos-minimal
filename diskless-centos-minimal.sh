#!/bin/sh
export ROOTDISK=/var/lib/diskless/centos7-minimal/
export DISKIMAGE=/root/tmp/diskless-image/diskless.img
export VMLINUZIMAGE=$(dirname $DISKIMAGE)/vmlinuz-$(basename $DISKIMAGE)
mkdir -p $ROOTDISK
cd $ROOTDISK
#yum group -y install --installroot=$ROOTDISK "Instalación mínima"
# install base binaries.  If you're not using puppet and IPA, this list can be trimmed.
yum -y install --releasever=7 --installroot=$ROOTDISK install basesystem filesystem bash passwd dhclient yum openssh-server openssh-clients nfs-utils ipa-client cronie-anacron selinux-policy-targeted vim-minimal 
cp /etc/yum.repos.d/elrepo.repo $ROOTDISK/etc/yum.repo.d/
yum -y install kernel-lt --enablerepo=elrepo-kernel --releasever=7 --installroot=$ROOTDISK

yum --installroot=$ROOTDISK/ --enablerepo=elrepo install basesystem filesystem bash passwd dhclient yum openssh-server openssh-clients nfs-utils ipa-client cronie-anacron selinux-policy-targeted vim-minimal kernel-lt


# Set the root password in the image
chroot $ROOTDISK passwd

cd $ROOTDISK
ln -s ./sbin/init ./init
cd

# Enable networking
echo "NETWORKING=yes" > $ROOTDISK/etc/sysconfig/network
chmod 644 $ROOTDISK/etc/sysconfig/network
echo "diskspacecheck=0" >> $ROOTDISK/etc/yum.conf
echo "keepcache=0" >> $ROOTDISK/etc/yum.conf

echo "ipa-client-install -force-join -principal admin@ICMAT.ES -w AdminIPA -unattended" >>  $ROOTDISK/etc/rc.local

cd $ROOTDISK

find | cpio -ocv | gzip -9 > $DISKIMAGE
chmod 644 $DISKIMAGE
cp $ROOTDISK/boot/vmlinuz-* $(dirname $DISKIMAGE)/vmlinuz-$(basename $DISKIMAGE)

chmod 644 $VMLINUZIMAGE
