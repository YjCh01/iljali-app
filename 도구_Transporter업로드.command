#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/upload_transporter.sh 2>/dev/null
exec ./scripts/upload_transporter.sh
