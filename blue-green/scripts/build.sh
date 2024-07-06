#!/bin/bash

cd ..
./mvnw clean install -DskipTests
./mvnw test
cd docker
./docker-build-deploy.sh $1

cd ..
IMAGE_EXISTS=$(printenv | grep -i "${IMAGE_DEPLOY}")