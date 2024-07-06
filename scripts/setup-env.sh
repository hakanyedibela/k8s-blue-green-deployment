#!/bin/sh

if [ $# -eq 0 ];
then
  echo "MMissing environment parameter. Use one of the following: 'dev' or 'prod'"
  exit 1
elif [ $# -gt 1 ];
then
  echo "Too many args! Use one of the following: 'dev' or 'prod'"
  exit 1
else
  if [ "$1" = "dev" ] || [ "$1" = "prod" ];
  then
    echo "You choose following environment $1"
    BUILD_ENV=$1
  else
    echo "$1 is not a valid environment"
    exit 1
  fi
fi

if [ "$BUILD_ENV" = "dev" ];
then
  # export variables, if you want to work with envsubst
  echo "Success Dev!"
fi

if [ "$BUILD_ARG" = "prod" ];
then
  # export variables, if you want to work with envsubst
  echo "Success Prod!"
fi

# Uncomment if you want to work with environment variables and envsubst
PATH_TO_ENV="../k8s/kustomize/overlays/${BUILD_ENV}"
#envsubst < ${PATH_TO_ENV}/kustomization.yaml

# kustomize build ../k8s/kustomize/overlays/${BUILD_ENV}
# OR 
kubectl kustomize ${PATH_TO_ENV}