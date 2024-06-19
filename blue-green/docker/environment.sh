#!/bin/bash

cd ..

DOCKERFILE="docker/Dockerfile.jvm"

COMMIT_HASH=$(git rev-parse --verify HEAD)
COMMIT_HASH_SHORT=$(git rev-parse --short HEAD)

PROJECT_NAME=$(./mvnw help:evaluate -Dexpression=project.name -q -DforceStdout)
#PROJECT_VERSION=$(./mvnw help:evaluate -Dexpression=project.version -q -DforceStdout)

# Push the image to local minikube registry
LOCAL_ENV="localhost:5000"

# Push the image to AWS EC2 registry
CLOUD_ENV="public.ecr.aws/123456"

if [ "local" = "${BUILD_ARG}" ];
then
  BUILD_ENVIRONMENT=$LOCAL_ENV
elif [ "cloud" = "${BUILD_ARG}" ];
then
  BUILD_ENVIRONMENT=$CLOUD_ENV
else
  echo "Something went wrong build argument can not be set!"
  exit 1
fi

IMAGE_NAME="${BUILD_ENVIRONMENT}/${PROJECT_NAME}-app"
IMAGE_TAG=${COMMIT_HASH_SHORT}