#!/bin/bash

USER="th"
HOST="cirrus.openavionics.eu"
REMOTE_IMG_DIR="~/public_html/omnia-images/"
REMOTE_TMP="~/tmp_omnia/"


push () {
	rsync -v -e ssh $1 $USER@$HOST:$2
}

if [ "$1" = "--all" ]; then
  push 'omnia-medkit-*.tar.gz' $REMOTE_IMG_DIR
  push 'omnia-medkit-*.tar.gz.md5' $REMOTE_IMG_DIR
fi

push './kernel/*.deb' $REMOTE_TMP

ssh $USER@$HOST "aptly repo add omnia $REMOTE_TMP/*.deb"

echo "Please go to ssh $USER@$HOST and run:
aptly publish update buster omnia

Please note: The repo setup is needed. Example:
aptly repo list
aptly repo create omnia
aptly repo add omnia *.deb
aptly repo show -with-packages omnia
aptly publish repo -distribution=buster omnia omnia
"

