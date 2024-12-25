#!/bin/bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# CA name
CA=ca
TF=${MYDIR}/kad-ca

kubectl create namespace cert-manager
kubectl create -n cert-manager secret generic cluster-issuer-kad --from-file=tls.crt=${TF}/ca.crt --from-file=tls.key=${TF}/ca.key
kubectl create -n cert-manager secret generic cluster-issuer-kad-ca --from-file=tls.crt=${TF}/ca.crt


