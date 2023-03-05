#!/bin/sh

# Exit on errors
set -e

chmod +x overlay/etc/local.d/headless.start
tar czvf headless.apkovl.tar.gz -C overlay etc --owner=0 --group=0

echo "Success! headless.apkovl.tar.gz generated"