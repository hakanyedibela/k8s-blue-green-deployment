#!/bin/bash

if [ $# -eq 0 ];
then
    echo "Missing build arguments! Possible build arguments: local or cloud"
    exit 1
elif [ $# -gt 1 ];
then
    echo "Too many arguments, please specify just one build argument: local or cloud"
    exit 1
else
    if [ "$1" = "local" ] || [ "$1" = "cloud" ];
    then
      echo "You choose the $1 build argument"
      BUILD_ARG=$1
    else
      echo "$1 is not a correct build argument! Please choose local or cloud"
      exit 1
    fi
fi

echo "$BUILD_ARG"
source environment.sh
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f ${DOCKERFILE} .
docker push ${IMAGE_NAME}:${IMAGE_TAG}