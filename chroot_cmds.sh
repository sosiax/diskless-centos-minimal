#!/bin/sh
ln -s ./sbin/init ./init

# forcing rc-local
chmod +x /etc/rc.d/rc.local
systemctl enable rc-local

# Updating fstab - TODO : check for cache device 
echo "192.168.1.133:/var/lib/diskless/centos7/usr        /usr                 nfs     ro,hard,intr,rsize=8192,wsize=8192,timeo=14,nosharecache,fsc 1 1" >> /etc/fstab
echo "nfs-lustre.icmat.es:/mnt/lustre_fs        /LUSTRE                 nfs     rw,hard,intr,rsize=8192,wsize=8192,timeo=14,nosharecache,fsc 1 1" >> /etc/fstab

# reducing locale
rm -f /etc/rpm/macros.image-language-conf
sed -i '/^override_install_langs=/d' /etc/yum.conf
yum reinstall -y glibc-common

localedef --list-archive | grep -v -i ^en| xargs localedef --delete-from-archive
mv -f /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
build-locale-archive

# Set the root password in the image
echo "root:2dminHPC19" | chpasswd

# Enable networking
echo "NETWORKING=yes" > /etc/sysconfig/network
chmod 644 /etc/sysconfig/network

# removing locale
cd /usr/share/locale/
ls -1 | grep -v local | grep -v en$ | xargs rm -fr 
cd -
