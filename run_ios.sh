#!/bin/sh
# Run on iPhone 14 simulator (starts Simulator if needed).
set -e
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export SSL_CERT_FILE="${SSL_CERT_FILE:-/etc/ssl/cert.pem}"

cd "$(dirname "$0")"

if ! flutter devices 2>/dev/null | grep -q "iPhone 14"; then
  echo "Starting iOS Simulator..."
  open -a Simulator
  xcrun simctl boot "449C8CC3-3F01-4B4F-B9F4-FEDDDC58AB37" 2>/dev/null || true
  for _ in $(seq 1 30); do
    if flutter devices 2>/dev/null | grep -q "iPhone 14"; then
      break
    fi
    sleep 2
  done
fi

if [ ! -d ios/Pods/Headers ]; then
  echo "Installing CocoaPods..."
  (cd ios && ./pod_install.sh)
fi

exec flutter run -d "iPhone 14" "$@"
