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

initializeFS(){
  fs=$1
  dest=$2
  echo "Inicilizing $fs"
  case $fs in 
     /var | /etc )
	   rm -fr $dest/*
       rsync -raAv --ignore-existing --exclude=*yum* $fs/ $dest/ 
       ;;
     /root )
       rsync -a --ignore-existing -f"+ */" -f"- *" $fs/ $dest/ > /dev/null
       ;;
     * )
       rm -fr $dest/*
       rsync -a --ignore-existing -f"+ */" -f"- *" $fs/ $dest/ > /dev/null
       ;;
  esac
  
} 

fail(){
  echo -e "ERROR: $1"
  exit 1
}

warning(){
  echo -e "WARNING: $1"
}

info(){
  echo -e "INFO: $1"
}

# load module
modprobe overlay || fail "ERROR: missing overlay kernel module"

# create a writable fs to then create our mountpoints
mount -t tmpfs tmpfs /mnt || fail "ERROR: could not create a temporary filesystem to mount the base filesystems for overlayfs"
mkdir -p /mnt/overlay/


#======================
# look for overlay LABEL
#======================
# create a writable fs to then create our mountpoints
#~ mount  LABEL=stlessST /mnt/overlay/ || \
  #~ mount -t tmpfs -o size=$((`free | grep Mem | awk '{ print $2 }'`/100))K tmpfs /mnt/overlay || \
    #~ fail "ERROR: could not create a temporary filesystem to mount the base filesystems for overlayfs"

#DIRLIST="/root /var /etc"
DIRLIST=""
[ ! -z ${DIRLIST} ] && \
  mount  LABEL=stlessST /mnt/overlay/ || \
    mount -t tmpfs tmpfs /mnt/overlay || \
      fail "ERROR: could not create a temporary filesystem to mount the base filesystems for overlayfs"
for fs in $DIRLIST
do
  mount -o remount $fs > /dev/null
  if [ $? -ne 0 ]
  then 
    fsname=`echo $fs | tr '/' '-'`
    mkdir -p /mnt/overlay/$fs/up
    mkdir -p /mnt/overlay/$fs/work
    initializeFS $fs /mnt/overlay/$fs/up 
    mount -t overlay overlay$fsname -o lowerdir=$fs,upperdir=/mnt/overlay/$fs/up,workdir=/mnt/overlay/$fs/work $fs || fail "ERROR mounting overlay on $fs"
  fi
done

   
# Check IP is 192.168.x.x
ip=`ip add | grep -ohE "192.168.([0-9]{1,3}[\.]){1}[0-9]{1,3}" | grep -v 255` || dhclient && sleep 1 && ip=`ip add | grep -ohE "192.168.([0-9]{1,3}[\.]){1}[0-9]{1,3}" | grep -v 255`
[ -z $ip ] && fail "No IP"

# Lustre mount - already in fstab
info "Mounting all filesystems"
mount -a 

#======================
# look for fscache LABEL
#======================
info "Checking FSCACHE"
read -r a FSCACHEDIR <<<`grep 'dir ' /etc/cachefilesd.conf`
[ -z ${FSCACHEDIR} ] && FSCACHEDIR=/var/cache/fscache
mkdir -p $FSCACHEDIR
mount -o remount LABEL=fscache &> /dev/null ||  \
  mount  LABEL=fscache $FSCACHEDIR || \
    mount -t tmpfs -o size=$((`free | grep Mem | awk '{ print $2 }'`/10))K tmpfs $FSCACHEDIR || \
      fail "ERROR: could not create a temporary filesystem to mount the base filesystems for overlayfs: $FSCACHEDIR"
service cachefilesd restart 
for dir in `mount | grep 'type nfs' | awk '{print $3}'`
do
  mount -o remount $dir
done

#======================
# look for scratch LABEL
#======================
info "Checking SCRATCH"
mkdir -p /scratch
mount -o remount LABEL=scratch &> /dev/null ||  \
  mount  LABEL=scratch /scratch || \
    warning "ERROR: could not mount scratch partition"  
    
for i in `mount | grep 'type nfs' | awk '{ print $3}'`
do 
   mount -o remount $i
done

# Setting up /etc
info "Setting up /etc"
cd /
tar xzf /usr/share/icmat/node-etc.tgz
sh /opt/icmat/sbin/build-login-files.sh merge
rsync -raAv /opt/icmat/config/odisea/ /
cd -

touch /var/log/lastlog

loadkeys es

sleep 1

#telinit 3

# Setting up IB
modprobe ib_ipoib
sleep 5
info "Configuring IB"
dev=$(ip link show | grep ib | grep 'state UP' | cut -d ':' -f2 | tr ' ' '\0')
ip=$(grep  `hostname -s`-ib /opt/icmat/config/common/etc/hosts.d/hosts.reference | cut -d ' ' -f1)
[[ ! -z $ip ]] && [[ ! -z $dev ]] && ip address add $ip/24 dev $dev 
if [ -z $ip ]; then warning "No IPoIB"; else info "IPoIB: $ip"; fi

# Setting time zone
info "Setting Zone Europe/Madrid"
timedatectl set-timezone Europe/Madrid

# Adding Ganglia user
info "Configuring ganglia user"
echo 'ganglia:x:989:985:Ganglia Monitoring System:/var/lib/ganglia:/sbin/nologin' >> /etc/passwd
echo 'ganglia:!!:18278::::::' >> /etc/shadow
echo 'ganglia:x:985:' >> /etc/group
echo 'ganglia:!::' >> /etc/gshadow

info "Running gmond"
/bin/systemctl enable gmond.service
/bin/systemctl start gmond.service

info "Running IPA client"
ipa-client-install --force-join --principal hostenrolluser@ICMAT.ES -w hostenrolluser --unattended --force 
#|| ipa-client-install --uninstall --unattended --force && ipa-client-install --force-join --principal hostenrolluser@ICMAT.ES -w hostenrolluser --unattended --force

info "Creating scratch dirs"
sh /opt/icmat/bin/scratch-init.sh

info "Setting up and running SGE daemon"
[ -z "$TERM" ] && export TERM=xterm
service sgeexecd softstop 
sge_file="/etc/init.d/sgeexecd /etc/init.d/sgeexecd.p6444 /etc/rc.d/init.d/sgeexecd /etc/rc.d/init.d/sgeexecd.p6444"
rm -fr $sge_file > /dev/null || warning "File /etc/init.d/sgeexecd.p6444 Cannot be removed!!"
ls $sge_file > /dev/null && warning "File /etc/init.d/sgeexecd.p6444 do exist!!"
cd /LUSTRE/apps/oge/
./install_execd < install-node.input
cd -

rsync -raAv /opt/icmat/config/odisea/ /
chkconfig --add sgeexecd
chkconfig --level 345 sgeexecd on
service sgeexecd start

#systemctl daemon-reload
#service sgeexecd.p6444 softstop
#sleep 1
#service sgeexecd.p6444 start

sleep 3

#systemctl isolate multi-user.target

#sleep 5 
info "Removing possible /run/nologin"
[ -e /run/nologin ] && rm -fr /run/nologin
info "Execution success"
