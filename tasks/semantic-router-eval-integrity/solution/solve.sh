#!/bin/bash
set -euo pipefail
cd /app
git apply /solution/patch.diff
