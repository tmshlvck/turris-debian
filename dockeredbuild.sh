#!/bin/bash

if ! docker images | cut -d" " -f1 | grep omniadeb-build >/dev/null; then
	docker build -t omniadeb-build .
fi

echo docker run --privileged -t -i --rm -v $(pwd):/root/omnia-debian omniadeb-build ./create-medkit.sh

