##!/bin/bash

export LC_ALL=C.UTF-8 #error codes now much easier to google



#Intended to build latest stable kernel from kernel.org to any deb-based distro using standard tools



#without those packages no magic sorry.

apt-get install -y unp kmod cpio unzip bzip2 make kernel-package bc build-essential libncurses5-dev fakeroot bison flex libelf-dev openssl libssl-dev curl wget jq lsb-release wget

echo "USAGE: sudo bash build_kernel.sh [5.5.1]"


if [ $# -ge 1 ]
then
    LATEST_STABLE=$1
else
    LATEST_STABLE=`curl -s https://www.kernel.org/releases.json | jq '.latest_stable.version' -r`
fi


ARG1=${1:-$LATEST_STABLE}


#root or GTFO
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi


#we getting date and using this to generate revision = it will be just A as it alphanumeric revision is required like REVISION="$DATE"A
#version may be only lowercase and - and +

DATE="$(date +%d%m%Y)"
REVISION="$DATE"A
TARGET_DIR="/usr/src" #where to compile. You wont need that but just in case.
PACKAGE_VERSION="kernel-org-to-debian"
CPU=$(nproc) #autodetect of all cores by default for compilation



#getting kernel

RELEASE_FILE="linux-$LATEST_STABLE.tar.xz"
RELEASE_URL="https://cdn.kernel.org/pub/linux/kernel/v$(echo $LATEST_STABLE | cut -d . -f 1 ).x/$RELEASE_FILE"

#compiing


cd $TARGET_DIR #less parameters


wget -c $RELEASE_URL

rm -r linux-$LATEST_STABLE #remove already unpacked sources
rm -r linux #remove default or old symlink

unp $RELEASE_FILE
ln -s linux-$LATEST_STABLE linux

cd $TARGET_DIR/linux

#current config copying
cp /boot/config-$(uname -r)  $TARGET_DIR/linux/.config

yes "" | make oldconfig

#changing debian certs keys off if kernel is default debian
sed -ri '/CONFIG_SYSTEM_TRUSTED_KEYS/s/=.+/=""/g' $TARGET_DIR/linux/.config


#minor it's about the naming
sed -ri '/CONFIG_BUILD_SALT=/s/=.+/=""/g' $TARGET_DIR/linux/.config
echo CONFIG_BUILD_SALT=\"$LATEST_STABLE-amd64\" >> $TARGET_DIR/linux/.config


fakeroot make-kpkg --initrd --append_to_version=$PACKAGE_VERSION --revision=$REVISION kernel_image kernel_headers -j$CPU
