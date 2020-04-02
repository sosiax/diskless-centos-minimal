#!/bin/sh
ln -s ./sbin/init ./init

# Enabling diskless-
chmod +x /root/diskless-boot.sh
systemctl enable diskless-boot


# Set the root password in the image
echo "2dminHPC19" > /tmp/pass
echo "2dminHPC19" >> /tmp/pass
passwd < /tmp/pass
rm /tmp/pass

# Enable networking
echo "NETWORKING=yes" > /etc/sysconfig/network
chmod 644 /etc/sysconfig/network

# reducing locale
rm -f /etc/rpm/macros.image-language-conf
sed -i '/^override_install_langs=/d' /etc/yum.conf
yum reinstall -y glibc-common

localedef --list-archive | grep -v -i ^en| xargs localedef --delete-from-archive
mv -f /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
# removing locale
cd /usr/share/locale/
ls -1 | grep -v local | grep -v en$ | xargs rm -fr 
cd -

build-locale-archive

