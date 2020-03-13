#!/bin/sh
TFTPBOOT_SRV="master:/var/lib/tftpboot/centos7/"
SCRITP_DIR=`readlink -f $(dirname $0)`
LOG=$SCRITP_DIR/$(basename $0).log
export ROOTDISK=/var/lib/diskless/centos7-minimal/
export DISKIMAGE=/root/tmp/diskless-image/diskless.img
export VMLINUZIMAGE=$(dirname $DISKIMAGE)/vmlinuz-$(basename $DISKIMAGE)

function MkInitrd {
  cd $ROOTDISK
  time find | cpio -oc | pigz -9 > $DISKIMAGE
  scp $DISKIMAGE $TFTPBOOT_SRV
}

function YumClean() {
  echo "Cleanning ..." >&2
  yum clean all --installroot=$ROOTDISK
  rm -fr $ROOTDISK/var/cache/yum
}

function ReduceDiskSpace () {
  cd $ROOTDISK
  BAK_LIST="var/lib/rpm var/lib/yum usr/lpp usr/share/man usr/share/doc boot/"
  tar -I pigz -cf $SCRITP_DIR/diskless.var.lib.rpm.tgz $BAK_LIST
  [ $? -eq 0 ] && echo "Tar compresion OK : $SCRITP_DIR/diskless.var.lib.rpm.tgz" && rm -fr $BAK_LIST
  
  tar -I pigz -cf $SCRITP_DIR/var.tgz var/
  [ $? -eq 0 ] && echo "Tar compression /var OK : $SCRITP_DIR/var.tgz"
  cd -
}

function ExpandDiskSpace () {
  cd $ROOTDISK
  tar -I pigz -xf $SCRITP_DIR/var.tgz var/
  tar -I pigz -xf $SCRITP_DIR/diskless.var.lib.rpm.tgz 
  cd -
}

function InstallSystem () {
  
  echo -n "Installing system ..... "
  
  yum group -y install --releasever=/ --installroot=$ROOTDISK "Instalación mínima" &>> $LOG
  cp /etc/yum.repos.d/elrepo.repo $ROOTDISK/etc/yum.repos.d/elrepo.repo
  yum -y install --releasever=/ --enablerepo=elrepo-kernel --installroot=$ROOTDISK  \
     basesystem filesystem bash passwd \
     dhclient openssh-server openssh-clients nfs-utils yum polkit ipa-client\
     vim-minimal util-linux shadow-utils kernel-lt net-tools cronie-anacron &>> $LOG
  
  # Configuring yum 
  echo "diskspacecheck=0" >> $ROOTDISK/etc/yum.conf
  echo "keepcache=0" >> $ROOTDISK/etc/yum.conf

  echo "Done"
}

if mount $ROOTDISK &> /dev/null 
then 
  echo "!!!! $ROOTDISK already mounted"
  read -n1 -r -p "Press any key to continue..." key
fi

mkdir -p $ROOTDISK/var/cache/yum
rsync -rAa $SCRITP_DIR/cache/yum $ROOTDISK/var/cache/yum 1> $LOG

mkdir -p $ROOTDISK

# Speed up image building -- Atention!
mount -t tmpfs -o size=4G,nr_inodes=400k tmpfs $ROOTDISK

#~ cd $ROOTDISK
#~ yum group -y install --releasever=/ --installroot=$ROOTDISK "Instalación mínima"

# install base binaries.  If you're not using puppet and IPA, this list can be trimmed.

InstallSystem
#~ echo -n "Installing system ..... "
#~ yum -y install --releasever=/ --enablerepo=elrepo-kernel --installroot=$ROOTDISK  \
#~ basesystem filesystem bash passwd \
#~ dhclient openssh-server openssh-clients nfs-utils yum polkit \
#~ vim-minimal util-linux shadow-utils kernel-lt net-tools cronie-anacron &>> $LOG
#~ echo "Done"

#~ # Configuring yum 
#~ echo "diskspacecheck=0" >> $ROOTDISK/etc/yum.conf
#~ echo "keepcache=0" >> $ROOTDISK/etc/yum.conf

# coping script files
cp /etc/profile.d/icmat.sh $ROOTDISK/etc/profile.d/icmat.sh	
cp -f $SCRITP_DIR/diskless-boot.sh $ROOTDISK/root/
cp -f $SCRITP_DIR/diskless-boot.service $ROOTDISK/usr/lib/systemd/system/ 
cp -f $SCRITP_DIR/chroot_cmds.sh $ROOTDISK/root/
chmod +x $ROOTDISK/root/chroot_cmds.sh 

# Adding ssh passthrought
mkdir -p $ROOTDISK/root/.ssh 
chmod 700 $ROOTDISK/root/.ssh 
cp -pr /root/.ssh/authorized_keys /root/.ssh/known_hosts $ROOTDISK/root/.ssh 

# Executing chroot commnads
chroot $ROOTDISK sh -x /root/chroot_cmds.sh 

# Getting kernel
#~ cp $ROOTDISK/boot/vmlinuz-* $VMLINUZIMAGE
#~ chmod 755 $VMLINUZIMAGE

##### Cleaning up
ReduceDiskSpace
#~ rm -fr $ROOTDISK/boot/vmlinuz-* $ROOTDISK/boot/vmlinuz-*
#~ rm -fr $ROOTDISK/boot/vmlinuz-* $ROOTDISK/boot/init*
#~ # Atention !!!
#~ rm -fr $ROOTDISK/usr/lib/firmware
#~ rm -fr $ROOTDISK/usr/share/man/
#~ rm -fr $ROOTDISK/usr/share/doc

#~ # Keeping cache files
#~ mkdir -p $SCRITP_DIR/cache/yum
#~ rsync -rAav $ROOTDISK/var/cache/yum $SCRITP_DIR/cache/yum 1>> $LOG
#~ rm -fr $ROOTDISK/var/cache/yum $ROOTDISK/var/lib/yum/*



#~ read -n1 -r -p "Press any key to continue..." key
MkInitrd
#~ cd $ROOTDISK 
#~ find | cpio -oc | gzip -9 > $DISKIMAGE 2>> $LOG
#~ chmod 644 $DISKIMAGE


