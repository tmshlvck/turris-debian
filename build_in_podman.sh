#!/bin/bash

set -eu -o pipefail

NAME="turrisbuild"
IMAGE="docker.io/library/ubuntu:20.04"

podman pull ${IMAGE}

cat >turris-setup.sh <<EOF
apt-get update
apt-get -y install u-boot-tools debootstrap qemu-user-static sudo
update-binfmts --enable
EOF

if podman ps -a | grep $NAME; then
	sudo podman start -a $NAME
else
	sudo podman pull $IMAGE
	sudo podman run \
		--name $NAME \
		--privileged \
		--rm \
		--network=host \
		-it \
		-v "$(pwd)":/repo \
		${IMAGE} \
		/bin/bash --init-file /repo/turris-setup.sh
#		/bin/bash -c "cd /repo && ./build.sh"
fi

rm turris-setup.sh

