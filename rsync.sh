#!/bin/bash

while true; do
  rsync --verbose --archive --compress --partial  --exclude=".git/" --exclude "fonts/" . jeef:/home/jstein/devel/airgap-dev-kit
  sleep 5
done