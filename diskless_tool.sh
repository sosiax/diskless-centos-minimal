#!/bin/bash
#
#  diskless_tool.sh
#  
#  Copyright 2018 Alfonso Nunez Salgado <anunez@cbm.csic.es>
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
#  25.01.2018 : Creación del archivo 
[[ ! -e $TMP ]] && TMP=/tmp/

TMP_PATH=$TMP/diskless/
DISK_PATH=/var/nfs/diskless/

[[ ! -e $TMP_PATH ]] && mkdir $TMP_PATH
[[ ! -e $DISK_PATH ]] && echo -e "ERROR: base dir do not exist : '$DISK_PATH'  \nCheck the script" && exit 1

function usage { 
  echo "Usage: $0 <COMMAND> <PATH> [DEST]" 1>&2; 
  echo "COMMANDS:" 1>&2; 
  echo "  clean     : Yum clean " 1>&2; 
  echo "  mkinitrd  : create initrd as is in directory " 1>&2; 
  echo "  mkminimal : create initrd removing all un neaded files (nfs mount) " 1>&2; 
  exit 1; 
  }

[ "$#" -lt 2 ] && echo "Too few commands" && usage

function MkInitrd {
  local path=$1
  local dest=$2
  cd $path
  rm -f $TMP_PATH/diskless.img 
  time find | cpio -oc | pigz -9 > $TMP_PATH/diskless.img 
  scp $TMP_PATH/diskless.img b744:/tftpboot/diskless_centos7/$dest
  mv $TMP_PATH/diskless.img $TMP_PATH/$dest
  ls -lh $TMP_PATH/$dest
  rm -f $TMP_PATH/$dest
}

function YumClean() {
  echo "Cleanning ..." >&2
    yum clean all --installroot=$path
    rm -fr $path/var/cache/yum
}

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

command=$1
path=$(readlink -e $2)
dest=$3

[[ ! -e $path ]] && echo "ERROR Path '$2' do not exit ...." >&2 && exit 1

case $command in
  clean )
    YumClean
    ;;
  mkinitrd)
    echo "mkinitrd" >&2
    [[ -z $dest ]] && echo "ERROR: No argument for initrd file" && usage
    MkInitrd $path $dest
    ;;
  mkminimal)
    [[ -z $dest ]] && echo "ERROR: No argument for initrd file" && usage
    YumClean
    bname=$(basename $path)
    [[ -e $DISK_PATH/${bname}.var.lib.rpm.tgz ]] && echo "Removing old TAR : $DISK_PATH/${bname}.var.lib.rpm.tgz" && rm -f $DISK_PATH/${bname}.var.lib.rpm.tgz
    cd $path
    
    # TODO: back list must be kernel configurable !!! : 3.10.0-693.11.6.el7.x86_64 is good
    #BAK_LIST="var/lib/rpm var/lib/yum usr/lpp usr/lib/firmware/ usr/share/man usr/share/doc boot/"
    BAK_LIST="var/lib/rpm var/lib/yum usr/lpp usr/share/man usr/share/doc boot/"
    tar -czf $DISK_PATH/${bname}.var.lib.rpm.tgz $BAK_LIST
    [ $? -eq 0 ] && echo "Tar compresion OK : $DISK_PATH/${bname}.var.lib.rpm.tgz" && rm -fr $BAK_LIST
    
    tar czf root/var.spool.torque.tgz var/spool/torque
    [ $? -eq 0 ] && echo "Tar compression /var/spool/torque OK : root/var.tgz" && rm -fr var/spool/torque/*
    
    tar czf root/var.mmfs.tgz var/mmfs/
    [ $? -eq 0 ] && echo "Tar compression /var/mmfs OK : root/var.mmfs.tgz" && rm -fr var/mmfs/*
    
    tar czf root/var.tgz var/
    [ $? -eq 0 ] && echo "Tar compression /var OK : root/var.tgz"
    
    MkInitrd $path $dest
    if [ -e $DISK_PATH/${bname}.var.lib.rpm.tgz ]
      then 
      tar -xzf $DISK_PATH/${bname}.var.lib.rpm.tgz
      tar -xzf root/var.mmfs.tgz
      tar -xzf root/var.spool.torque.tgz
    else
      echo "FATAL!! file $TMP_PATH/${bname}.var.lib.rpm.tgz do not exist!"
      exit 1
    fi
    exit 1
    ;;
  *)
    echo "Inavalid command : $command" >&2
    usage
    ;;
esac
