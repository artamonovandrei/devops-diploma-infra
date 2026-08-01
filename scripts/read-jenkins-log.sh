#!/bin/bash
set -e
BUILD_DIR=/var/lib/jenkins/jobs/microservices-app/branches/main/builds
LATEST=$(sudo ls -1 "$BUILD_DIR" | grep -E '^[0-9]+$' | sort -n | tail -1)
echo "LATEST_BUILD=$LATEST"
sudo grep -nE 'Error|ERROR|unauthorized|denied|No such|Push to|Deploy to|Unit Tests|Build Images|Finished:|docker login|docker push|kubectl' "$BUILD_DIR/$LATEST/log" | tail -50
echo '===== TAIL ====='
sudo tail -40 "$BUILD_DIR/$LATEST/log"
