#!/usr/bin/env bash

kubectl label node c1-control-plane topology.kubernetes.io/zone=quorum dc=quorum --overwrite

kubectl label node c1-worker  topology.kubernetes.io/zone=dc1 dc=dc1 --overwrite
kubectl label node c1-worker2 topology.kubernetes.io/zone=dc1 dc=dc1 --overwrite
kubectl label node c1-worker3 topology.kubernetes.io/zone=dc1 dc=dc1 --overwrite

kubectl label node c1-worker4 topology.kubernetes.io/zone=dc2 dc=dc2 --overwrite
kubectl label node c1-worker5 topology.kubernetes.io/zone=dc2 dc=dc2 --overwrite
kubectl label node c1-worker6 topology.kubernetes.io/zone=dc2 dc=dc2 --overwrite

kubectl label node c1-worker7 topology.kubernetes.io/zone=dcq dc=dcq --overwrite
kubectl label node c1-worker8 topology.kubernetes.io/zone=dcq dc=dcq --overwrite
kubectl label node c1-worker9 topology.kubernetes.io/zone=dcq dc=dcq --overwrite

kubectl taint node c1-worker7 redis-dc=dcq:NoSchedule --overwrite
kubectl taint node c1-worker8 redis-dc=dcq:NoSchedule --overwrite
kubectl taint node c1-worker9 redis-dc=dcq:NoSchedule --overwrite
