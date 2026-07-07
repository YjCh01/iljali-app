#!/bin/bash
cd "$(dirname "$0")"
chmod +x CocoaPods설치.sh scripts/ensure_cocoapods.sh scripts/install_cocoapods_mac.sh scripts/install_ruby33_mac.sh scripts/install_openssl_mac.sh scripts/install_libyaml_mac.sh scripts/ensure_ssl_certs.sh 2>/dev/null
exec ./CocoaPods설치.sh
