#!/bin/bash
cd "$(dirname "$0")"
source scripts/environments.env
exec open "${ILJARI_WEB_URL}/"
