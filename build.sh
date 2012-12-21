#!/bin/bash

# make sure we have dependencies 
hash mkisofs 2>/dev/null || { echo >&2 "ERROR: mkisofs not found.  Aborting."; exit 1; }

# TODO install guest additions once box is intalled (currently box
# self-installs with hardcoded version number)

# ISO_GUESTADDITIONS="/usr/share/virtualbox/VBoxGuestAdditions.iso"

# if [ ! -f $ISO_GUESTADDITIONS ]; then
#     sudo apt-get install iso-guest-additions-iso
# fi

set -o nounset
set -o errexit
#set -o xtrace

# Configurations
BOX="ubuntu-precise-32"
BASE_NAME="ubuntu-12.04.1-alternate-i386.iso"
ISO_URL="http://releases.ubuntu.com/precise/$BASE_NAME"
ISO_MD5="b4512076d85a1056f8a35f91702d81f9"

FOLDER_BASE=`pwd`
FOLDER_ISO="${FOLDER_BASE}/iso"
FOLDER_BUILD="${FOLDER_BASE}/working"
FOLDER_VBOX="${FOLDER_BUILD}/vbox"
FOLDER_ISO_CUSTOM="${FOLDER_BUILD}/iso/custom"
FOLDER_ISO_INITRD="${FOLDER_BUILD}/iso/initrd"

PACKAGE="${FOLDER_BASE}/package.box"

# clean build environment before starting

while VBoxManage list runningvms | grep "${BOX}" >/dev/null; do
    echo "Box ${BOX} is running,.. halting"
    VBoxManage controlvm ${BOX} poweroff
    sleep 1
done

if VBoxManage showvminfo "${BOX}" >/dev/null 2>/dev/null; then
    echo "Box ${BOX} already exists,.. deleting"
    VBoxManage unregistervm ${BOX} --delete
fi 

if [ -d "${FOLDER_BUILD}" ]; then
    echo "Cleaning build directory ..."
    sudo chmod -R u+w "${FOLDER_BUILD}"
    sudo rm -rf "${FOLDER_BUILD}"
    mkdir -p "${FOLDER_BUILD}"
fi

if [ -e "${PACKAGE}" ]; then
    rm "${PACKAGE}"
fi

if [ -e ${FOLDER_ISO}/custom.iso ]; then
    rm ${FOLDER_ISO}/custom.iso
fi

# Setting things back up again
mkdir -p "${FOLDER_ISO}"
mkdir -p "${FOLDER_BUILD}"
mkdir -p "${FOLDER_VBOX}"
mkdir -p "${FOLDER_VBOX}/${BOX}"
#mkdir -p "${FOLDER_ISO_CUSTOM}"
mkdir -p "${FOLDER_ISO_INITRD}"

ISO_FILENAME="${FOLDER_ISO}/${BASE_NAME}"
INITRD_FILENAME="${FOLDER_ISO}/initrd.gz"

if [ ! -e "${ISO_FILENAME}" ]; then
    echo "Downloading `basename ${ISO_URL}` ..."
    curl --output "${ISO_FILENAME}" -L "${ISO_URL}"
fi

  # make sure download is right...
ISO_HASH=`md5sum "${ISO_FILENAME}" | cut -d" " -f 1`

if [ "${ISO_MD5}" != "${ISO_HASH}" ]; then
    echo "ERROR: MD5 does not match. Got ${ISO_HASH} instead of ${ISO_MD5}. Aborting."
    exit 1
fi

# customize it
#echo "Creating Custom ISO"

if [ -e "${FOLDER_ISO}/original" ]; then
    sudo rm -rf "${FOLDER_ISO}/original"
fi

mkdir "${FOLDER_ISO}/original" "${FOLDER_ISO_CUSTOM}"
sudo mount -o loop "${ISO_FILENAME}" "${FOLDER_ISO}/original" >/dev/null

cp -r ${FOLDER_ISO}/original/* ${FOLDER_ISO_CUSTOM}/
cp -r "${FOLDER_ISO}/original/.disk" "${FOLDER_ISO_CUSTOM}/"

sudo umount "${FOLDER_ISO}/original"

  # backup initrd.gz
echo "Backing up current init.rd ..."
chmod u+w "${FOLDER_ISO_CUSTOM}/install" "${FOLDER_ISO_CUSTOM}/install/initrd.gz"
mv "${FOLDER_ISO_CUSTOM}/install/initrd.gz" "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org"

  # stick in our new initrd.gz
echo "Installing new initrd.gz ..."
cd "${FOLDER_ISO_INITRD}"
sudo gunzip -c "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org" | sudo cpio -id
    #sudo chown $EUID:$EUID ${FOLDER_ISO_CUSTOM} -R
cd "${FOLDER_BASE}"
cp preseed.cfg "${FOLDER_ISO_INITRD}/preseed.cfg"
cd "${FOLDER_ISO_INITRD}"
sudo chown 0:0 * -R
find . | sudo cpio --create --format='newc' | gzip  > ${FOLDER_ISO_CUSTOM}/install/initrd.gz

  # clean up permissions
echo "Cleaning up Permissions ..."
sudo chmod u-w "${FOLDER_ISO_CUSTOM}/install" "${FOLDER_ISO_CUSTOM}/install/initrd.gz" "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org"

  # replace isolinux configuration
echo "Replacing isolinux config ..."
cd "${FOLDER_BASE}"
sudo chmod u+w ${FOLDER_ISO_CUSTOM}/isolinux ${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg
sudo rm ${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg
sudo cp isolinux.cfg ${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg
sudo chmod u+w ${FOLDER_ISO_CUSTOM}/isolinux/isolinux.bin

  # add post_install script
#cp "${FOLDER_BASE}/post_install.conf" "${FOLDER_ISO_CUSTOM}"
cp ${FOLDER_BASE}/rc.local ${FOLDER_ISO_CUSTOM}

echo "Running mkisofs ..."
sudo mkisofs -r -V "Custom Ubuntu Install CD" \
    -cache-inodes -quiet \
    -J -l -b isolinux/isolinux.bin \
    -c isolinux/boot.cat -no-emul-boot \
    -boot-load-size 4 -boot-info-table \
    -o ${FOLDER_ISO}/custom.iso ${FOLDER_ISO_CUSTOM}

sudo chown $EUID:$EUID "${FOLDER_ISO}/custom.iso"


# create virtual machine

echo "Creating VM"
VBoxManage createvm \
    --name "${BOX}" \
    --ostype Ubuntu \
    --register \
    --basefolder "${FOLDER_VBOX}"

VBoxManage modifyvm "${BOX}" \
    --memory 360 \
    --boot1 dvd \
    --boot2 disk \
    --boot3 none \
    --boot4 none \
    --vram 12 \
    --pae on \
    --rtcuseutc on

VBoxManage storagectl "${BOX}" \
    --name "IDE Controller" \
    --add ide \
    --controller PIIX4 \
    --hostiocache on

VBoxManage storageattach "${BOX}" \
    --storagectl "IDE Controller" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium "${FOLDER_ISO}/custom.iso"


VBoxManage storagectl "${BOX}" \
    --name "SATA Controller" \
    --add sata \
    --controller IntelAhci \
    --sataportcount 1 \
    --hostiocache off

VBoxManage createhd \
    --filename "${FOLDER_VBOX}/${BOX}/${BOX}.vdi" \
    --size 40960

VBoxManage storageattach "${BOX}" \
    --storagectl "SATA Controller" \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium "${FOLDER_VBOX}/${BOX}/${BOX}.vdi"

#VBoxManage startvm "${BOX}" -type "headless"
VBoxManage startvm "${BOX}"

echo -n "Waiting for installer to finish "
while VBoxManage list runningvms | grep "${BOX}" >/dev/null; do
    sleep 20
    echo -n "."
done
echo ""

  # Forward SSH
VBoxManage modifyvm "${BOX}" \
    --natpf1 "guestssh,tcp,,2222,,22"


# TODO
# Attach guest additions iso
# VBoxManage storageattach "${BOX}" \
#     --storagectl "IDE Controller" \
#     --port 1 \
#     --device 0 \
#     --type dvddrive \
#     --medium "${ISO_GUESTADDITIONS}"

VBoxManage startvm "${BOX}"
#VBoxManage startvm "${BOX}" -type "headless"

  # get private key
curl --output "${FOLDER_BUILD}/id_rsa" "https://raw.github.com/mitchellh/vagrant/master/keys/vagrant"
chmod 600 "${FOLDER_BUILD}/id_rsa"

#ssh -i "${FOLDER_BUILD}/id_rsa" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 2222 vagrant@127.0.0.1 "sudo shutdown -h now"

#ssh -i "${FOLDER_BUILD}/id_rsa" -o KbdInteractiveAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 2222 vagrant@127.0.0.1 "sudo shutdown -h now"

echo -n "Waiting for machine to finish bootstrap install and shutdown "
while VBoxManage list runningvms | grep "${BOX}" >/dev/null; do
    sleep 20
    echo -n "."
done

echo ""
    
VBoxManage modifyvm "${BOX}" --natpf1 delete "guestssh"

echo "Packaging and adding vagrant box ${BOX}"
vagrant package --base "${BOX}"
vagrant box remove ${BOX} 2>/dev/null
vagrant box add ${BOX} package.box
