#!/usr/bin/env bash

kubectl create ns redis
kubens redis

#VERSION=`curl --silent https://api.github.com/repos/RedisLabs/redis-enterprise-k8s-docs/releases/latest | grep tag_name | awk -F'"' '{print $4}'`
VERSION=v8.0.10-23

kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/$VERSION/bundle.yaml

kubectl apply -f redis-operator-rbac.yaml
