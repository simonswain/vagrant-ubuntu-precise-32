#!/bin/bash

FOLDER_BASE=`pwd`
FOLDER_ISO="${FOLDER_BASE}/iso"
FOLDER_BUILD="${FOLDER_BASE}/working"

if [ -e "${FOLDER_BUILD}" ]; then
    sudo chown $EUID -R "${FOLDER_BUILD}"
    sudo chmod -R u+x "${FOLDER_BUILD}"
    rm -rf "${FOLDER_BUILD}"
fi

if [ -e "${FOLDER_ISO}" ]; then
    sudo chown $EUID -R "${FOLDER_ISO}"
    sudo chmod -R u+x "${FOLDER_ISO}"
    rm -rf "${FOLDER_ISO}"
fi

if [ -e "${FOLDER_BASE}/package.box" ]; then
    rm -rf "${FOLDER_BASE}/package.box"
fi

cd test
vagrant destroy >/dev/null
