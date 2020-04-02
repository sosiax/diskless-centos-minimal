#!/bin/sh

#  diskless-centos-minimal.sh
#  
#  Copyright 2020 Alfonso Núñez Salgado <anunez@icmat.es>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#  
#  

function usage { 
  echo "Usage: $0 <COMMAND> <PATH> [DEST]" 1>&2; 
  echo "COMMANDS:" 1>&2; 
  echo "  clean     : Yum clean " 1>&2; 
  echo "  mkinitrd  : create initrd as is in directory " 1>&2; 
  echo "  mkminimal : create initrd removing all un neaded files (nfs mount) " 1>&2; 
  echo "  intall    : install base system " 1>&2; 
  echo "  reduce    : copy needed scripts and other stuff" 1>&2; 
  echo "  expand    : reverse of reduce" 1>&2; 
  echo "  save      : full local copy" 1>&2; 
  echo "  restore   : restore ful local copy" 1>&2; 
}

#=======================================================================
# GLOBAL VARIABLES
#=======================================================================
TFTPBOOT_SRV="master:/var/lib/tftpboot/centos7/"
SCRITP_DIR=`readlink -f $(dirname $0)`
LOG=$SCRITP_DIR/$(basename $0).log
export ROOTDISK=/var/lib/diskless/centos7-minimal/
export DISKIMAGE=/root/tmp/diskless-image/diskless.img
export VMLINUZIMAGE=$(dirname $DISKIMAGE)/vmlinuz-$(basename $DISKIMAGE)

#============================
#  MkInitrd
#============================
function MkInitrd {
  echo "===================================="
  echo "Creating initrd ..... "
  echo "===================================="
  cd $ROOTDISK
  time find | cpio -oc | pigz -9 > $DISKIMAGE
  scp $DISKIMAGE $TFTPBOOT_SRV
}

#============================
#  MkInitrd
#============================
function YumClean() {
  echo "Cleanning yum ..." >&2
  yum clean all --enablerepo=* --installroot=$ROOTDISK
  rm -fr $ROOTDISK/var/cache/yum
}

#============================
#  MkInitrd
#============================
function ReduceDiskSpace () {
  echo "===================================="
  echo "Reducing Disk space "
  echo "===================================="
  
  [[ -e $SCRITP_DIR/diskless.var.lib.rpm.tgz ]] && echo "Removing old TAR : $DISK_PATH/diskless.var.lib.rpm.tgz" && rm -f $DISK_PATH/diskless.var.lib.rpm.tgz
  
  cd $ROOTDISK
  #BAK_LIST="var/lib/rpm var/lib/yum usr/share/man usr/share/doc boot/ usr/lib/firmware"
  BAK_LIST="var/lib/rpm var/lib/yum usr/share/man usr/share/doc boot/ "
  tar -I pigz -cf $SCRITP_DIR/diskless.var.lib.rpm.tgz $BAK_LIST
  [ $? -eq 0 ] && echo "Tar compresion OK : $SCRITP_DIR/diskless.var.lib.rpm.tgz" && rm -fr $BAK_LIST
  
  tar -I pigz -cf $SCRITP_DIR/var.tgz var/
  [ $? -eq 0 ] && echo "Tar compression /var OK : $SCRITP_DIR/var.tgz"
  cd -
  
  # Configuring yum 
  echo "diskspacecheck=0" >> $ROOTDISK/etc/yum.conf
  echo "keepcache=0" >> $ROOTDISK/etc/yum.conf
}

#============================
#  MkInitrd
#============================
function ExpandDiskSpace () {
  echo "===================================="
  echo "Extranting tgz .... "
  echo "===================================="
  cd $ROOTDISK
  tar -I pigz -xf $SCRITP_DIR/var.tgz var/
  tar -I pigz -xf $SCRITP_DIR/diskless.var.lib.rpm.tgz 
  # Configuring yum 
  sed -i '/^diskspacecheck=/d' /etc/yum.conf
  sed -i '/^keepcache=/d' /etc/yum.conf
  cd -
}

#============================
#  MkInitrd
#============================
function InstallSystem () {
  echo "===================================="
  echo "Installing system ..... "
  echo "===================================="
  
  yum group -y install --releasever=/ --installroot=$ROOTDISK "Instalación mínima" 
  yum -y install --releasever=/ --enablerepo=elrepo-kernel --installroot=$ROOTDISK \
     kernel-lt 
  #cp /etc/yum.repos.d/elrepo.repo $ROOTDISK/etc/yum.repos.d/elrepo.repo
  #~ yum -y install --releasever=/ --enablerepo=elrepo-kernel --installroot=$ROOTDISK  \
     #~ basesystem filesystem bash passwd \
     #~ dhclient openssh-server openssh-clients nfs-utils yum polkit ipa-client\
     #~ vim-minimal util-linux shadow-utils kernel-lt net-tools cronie-anacron 
  #~ yum -y remove --releasever=/ --enablerepo=elrepo-kernel --installroot=$ROOTDISK "kernel-3*"
  
  #~ yum -y install --releasever=/ --enablerepo=elrepo-kernel --installroot=$ROOTDISK  \
     #~ basesystem filesystem bash passwd \
     #~ dhclient openssh-server openssh-clients nfs-utils yum polkit ipa-client\
     #~ vim-minimal util-linux shadow-utils kernel-lt net-tools cronie-anacron 
  
  #~ yum -y install --releasever=/ --enablerepo=elrepo-kernel --installroot=$ROOTDISK  \
     #~ basesystem filesystem bash passwd \
     #~ dhclient openssh-server openssh-clients nfs-utils yum polkit\
     #~ util-linux kernel-lt 
  
  
  # Configuring yum 
  echo "diskspacecheck=0" >> $ROOTDISK/etc/yum.conf
  echo "keepcache=0" >> $ROOTDISK/etc/yum.conf
}

#============================
#  Prepare
#============================
function PrepareSystem(){
  echo "===================================="
  echo "Preparing system ..... "
  echo "===================================="
  # coping script files
  #~ cp /etc/profile.d/icmat.sh $ROOTDISK/etc/profile.d/icmat.sh	
  #~ cp -f $SCRITP_DIR/diskless-boot.sh $ROOTDISK/root/
  #~ cp -f $SCRITP_DIR/diskless-boot.service $ROOTDISK/usr/lib/systemd/system/ 
  
  #~ # Adding ssh passthrought
  #~ mkdir -p $ROOTDISK/root/.ssh 
  #~ chmod 700 $ROOTDISK/root/.ssh 
  #~ cp -pr /root/.ssh/authorized_keys /root/.ssh/known_hosts $ROOTDISK/root/.ssh 
  chmod 600 $SCRITP_DIR/fs/etc/ssh/*
  rsync -raALv $SCRITP_DIR/fs/ $ROOTDISK/
  mkdir -p $ROOTDISK/opt/icmat/
  rsync -raA --delete /opt/icmat/ $ROOTDISK/opt/icmat/
  
  # Executing chroot commnads
  cp -f $SCRITP_DIR/chroot_cmds.sh $ROOTDISK/root/
  chmod +x $ROOTDISK/root/chroot_cmds.sh 
  chroot $ROOTDISK sh -x /root/chroot_cmds.sh 
}

#============================
#  Save
#============================
function Save(){
  echo "===================================="
  echo "Saving to $SCRITP_DIR/diskless.full.tgz ..... "
  echo "===================================="
  tar -I pigz -cf $SCRITP_DIR/diskless.full.tgz $ROOTDISK
}

#============================
#  Restore
#============================
function Restore(){
  echo "===================================="
  echo "Restoring from $SCRITP_DIR/diskless.full.tgz ..... "
  echo "===================================="
  cd $ROOTDISK
  tar -I pigz -xf $SCRITP_DIR/diskless.full.`date +%Y-%m-%d`.tgz 
  cd -
}

#=============================================
#  Main
#=============================================

#Getting posible options (not enabled options)
while getopts ":a:" opt; do
  case $opt in
    a)
      echo "-a was triggered, Parameter: $OPTARG" >&2
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
    *)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

[ $# -eq 0 ] && usage && exit 

# Checking fs mounted
if mount $ROOTDISK &> /dev/null 
then 
  umount $ROOTDISK
  echo "!!!! $ROOTDISK already mounted"
  read -n1 -r -p "Press any key to continue..." key
else
  mkdir -p $ROOTDISK
  # Speed up image building -- Atention!
  mount -t tmpfs -o size=4G,nr_inodes=400k tmpfs $ROOTDISK
fi

# Executing commnad
while [[ $# -gt 0 ]]
do
  command=$1
  case $command in
    clean )
      YumClean
      shift;;
    mkinitrd )
      echo "mkinitrd" >&2
      MkInitrd 
      shift;;
    mkminimal )
      YumClean
      ReduceDiskSpace
      MkInitrd 
      ExpandDiskSpace
      shift;;
    install )
      InstallSystem
      shift;;
    prepare )
      PrepareSystem
      shift;;
    reduce )
      ReduceDiskSpace
      shift;;
    expand )
      ExpandDiskSpace
      shift;;
    save )
      Save
      shift;;
    restore )
      Restore
      shift;;
    *)
      echo "Inavalid command : $command" >&2
      usage
      shift;;
  esac
done
  





