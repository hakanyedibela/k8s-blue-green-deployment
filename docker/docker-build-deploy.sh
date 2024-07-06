#!/bin/bash

PERSONAL="personal"
CLOUD="cloud"

if [ $# -eq 0 ];
then
    echo "Missing build arguments! Possible build arguments: personal or cloud"
    exit 1
elif [ $# -gt 1 ];
then
    echo "Too many arguments, please specify just one build argument: personal or cloud"
    exit 1
else
    if [ "$1" = "${PERSONAL}" ] || [ "$1" = "${CLOUD}" ];
    then
      echo "You choose the $1 build argument"
      BUILD_ARG=$1
    else
      echo "$1 is not a correct build argument! Please choose personal or cloud"
      exit 1
    fi
fi

echo "$BUILD_ARG"
source environment.sh
# Docker Build and Push to your own repo. Change also the PERSONAL_ENV Variable in environment.sh
# docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f ${DOCKERFILE} .
# docker push ${IMAGE_NAME}:${IMAGE_TAG}

export DEPLOY_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
echo "DEPLOYMENT IMAGE: ${DEPLOY_IMAGE}"