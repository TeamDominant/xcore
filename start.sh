#!/bin/bash

REPO_URL="https://github.com/cortez24rus/reverse_proxy/archive/refs/heads/main.tar.gz"
DIR_REVERSE_PROXY="/usr/local/reverse_proxy/"

mkdir -p "${DIR_REVERSE_PROXY}repo/"
wget -qO- $REPO_URL | tar xz --strip-components=1 -C "${DIR_REVERSE_PROXY}repo/"

chmod +x "${DIR_REVERSE_PROXY}repo/reverse_proxy.sh"
ln -sf ${DIR_REVERSE_PROXY}repo/reverse_proxy.sh /usr/local/bin/reverse_proxy

bash "${DIR_REVERSE_PROXY}repo/reverse_proxy.sh"