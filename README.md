# Dual datacenter (stretched) Kubernetes with Redis Enterprise

A small Kind-based lab to simulate a **2 data center + 1 witness/quorum** Kubernetes topology with Redis Enterprise.

This project includes:

- a `cluster.yaml` Kind config with:
  - one control-plane (good enough as we assume we won't destroy it)
  - `dc2` control-plane
  - `quorum` control-plane
  - three worker in `dc1`
  - three worker in `dc2`
- a `kubectl`-based script to simulate a scheduler-level `dc2` failure
- a Docker-level script to simulate a harder `dc2` outage for Kind node containers


We use a total of 6 worker so that we have enough worker nodes to deploy 3 pods (node) of Redis Enterprise and that DC have enough worker capacity free to trigger Redis Enterprise statefulset pod automatic recovery when appropriate.
By default Redis Enterprise K8s scheduling will not put multiple pods on same workers nodes.


## TODO

- Can't start Redis Enterprise with 
```
  rackAwarenessNodeLabel: topology.kubernetes.io/zone
```
but works with
```
  rackAwarenessNodeLabel: dc
```

- Quorum loss with DC2 when having one cluster (3+3) database and one ha (1+1) database.



## Prerequisites

- Docker
- kind
- kubectl

## Create the cluster

```bash
kind create cluster --config cluster.yaml

./labels.sh

kubectl get nodes --show-labels
```

## Redis Enterprise on K8s setup

Assumption that we work in the `redis` namespace

```bash
install.sh

kubens redis

kubectl apply -f redis-operator-rbac.yaml

kubectl apply -f rec.yaml
```

## Simulate DC2 outgage (docker-level hard outage)

Because Kind nodes are Docker containers, you can simulate a rougher outage by pausing or stopping the DC2 node containers.

```bash
./simulate-dc2-hard-failure.sh status

#optional
./simulate-dc2-hard-failure.sh pause

# hard failure
./simulate-dc2-hard-failure.sh stop

# a bit later
./simulate-dc2-hard-failure.sh restore
```

Modes:

- `pause`: simulate a hung or partitioned node
- `stop`: simulate a power-off style outage
- `restore`: unpause or restart affected node containers
- `status`: show Docker and Kubernetes state

Notes:

- `pause` is good for observing `NotReady` behavior and delayed eviction
- `stop` is good for observing pod rescheduling after hard loss
- if you stop too many control-plane nodes, the Kubernetes API can become unavailable


## Cleanup

```bash
kind delete cluster --name c1
```
