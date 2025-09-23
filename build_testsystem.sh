#!/bin/bash

set -e  # Exit on any error

./build_and_push.sh memory-allocator
./build_and_push.sh cpu-load-generator

# Build TeaStore using Docker Maven builder
echo "Building TeaStore with Maven..."

docker run --rm \
    -v "$(pwd)/TeaStore":/usr/src/app \
    -w /usr/src/app \
    maven:3.8.4-openjdk-11 \
    mvn clean install -DskipTests > TeaStore/maven-build.log 2>&1

echo "Maven build completed! Output saved to TeaStore/maven-build.log"

./build_and_push.sh TeaStore/utilities/tools.descartes.teastore.kieker.rabbitmq
