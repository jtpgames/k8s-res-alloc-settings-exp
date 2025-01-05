#!/bin/bash

CONTAINER=$1

podman ps | grep $CONTAINER 2>/dev/null 1>&2
if [ $? -ne 0 ]; then
	podman start $CONTAINER
fi

podman exec --interactive --tty $CONTAINER /bin/bash
