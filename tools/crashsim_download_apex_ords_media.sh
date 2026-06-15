#!/usr/bin/env bash
set -euo pipefail

MEDIA_DIR="${MEDIA_DIR:-/u01/app/oracle/product/crashsim_apex_ords/media}"
mkdir -p "$MEDIA_DIR"
cd "$MEDIA_DIR"

download_if_missing() {
  local url="$1"
  local file="$2"
  if [[ -s "$file" ]]; then
    echo "Already present: $file"
    return 0
  fi
  echo "Downloading $url"
  curl -fL --connect-timeout 20 --retry 3 --retry-delay 5 -o "${file}.part" "$url"
  mv "${file}.part" "$file"
  ls -lh "$file"
}

download_if_missing "https://download.oracle.com/otn_software/apex/apex_26.1_en.zip" "apex_26.1_en.zip"
download_if_missing "https://download.oracle.com/otn_software/java/ords/ords-26.1.2.140.1916.zip" "ords-26.1.2.140.1916.zip"
