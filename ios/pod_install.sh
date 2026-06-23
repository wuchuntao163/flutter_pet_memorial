#!/bin/sh
# Bootstrap CocoaPods (UTF-8 + SSL certs).
set -e
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export SSL_CERT_FILE="${SSL_CERT_FILE:-/etc/ssl/cert.pem}"
cd "$(dirname "$0")"
pod install "$@"
