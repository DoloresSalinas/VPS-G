#!/bin/bash
set -e
TARGET=$1
if [ "$TARGET" != "blue" ] && [ "$TARGET" != "green" ]; then
  exit 1
fi
if [ "$TARGET" = "blue" ]; then
  cp nginx/blue.conf nginx/active.conf
  echo blue > nginx/ACTIVE
else
  cp nginx/green.conf nginx/active.conf
  echo green > nginx/ACTIVE
fi
