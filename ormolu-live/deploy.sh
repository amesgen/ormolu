#!/usr/bin/env bash
set -eo pipefail
ORMOLU_LIVE=$(nix build -L -j 1 --print-out-paths .#ormoluLive/website)
netlify deploy --alias=$(git log -1 --format="%H") -d $ORMOLU_LIVE
netlify deploy --prod -d $ORMOLU_LIVE
