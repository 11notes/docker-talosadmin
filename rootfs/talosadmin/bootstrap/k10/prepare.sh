#!/bin/sh
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/refs/tags/v8.6.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/refs/tags/v8.6.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/refs/tags/v8.6.0/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/refs/tags/v8.6.0/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/refs/tags/v8.6.0/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml