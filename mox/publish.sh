#!/bin/bash

USER="th"
HOST="cirrus.openavionics.eu"
REMOTE_IMG_DIR="~/public_html/mox-images/"
REMOTE_TMP="~/tmp_mox/"


push () {
	rsync -v -e ssh $1 $USER@$HOST:$2
}


push 'mox-sdimg-*.tar.gz' $REMOTE_IMG_DIR
push 'mox-sdimg-*.tar.gz.md5' $REMOTE_IMG_DIR

push './kernel/*.deb' $REMOTE_TMP

ssh $USER@$HOST "aptly repo add mox $REMOTE_TMP/*.deb"

echo "Please go to ssh $USER@$HOST and run:
aptly publish update buster mox

Please note: The repo setup is needed. Example:
aptly repo list
aptly repo create mox
aptly repo add mox *.deb
aptly repo show -with-packages mox
aptly publish repo -distribution=buster mox mox
"

