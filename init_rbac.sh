#!/bin/bash

if [ $# -ne 1 ] ; then
	echo "usage : $0 ID_APPLICATION_DOCKER"
	exit 1
fi
ID_APPLICATION_DOCKER=$1
DIRECTORY_TEMPLATE=$(dirname $0)/rbac/template
DIRECTORY_RBAC=$(dirname $0)/rbac/${ID_APPLICATION_DOCKER}
LIST_ENVS_HORSPROD="int rec pprod"
LIST_NAMESPACES_DTR_HORSPROD="commit release"

if [ "${ID_APPLICATION_DOCKER}" = "" ] ; then
	echo "ERROR"
	exit 1
fi

echo "Cluster horsprod"
mkdir -p ${DIRECTORY_RBAC}/horsprod
echo "DEBUG : delete DIRECTORY_RBAC ${DIRECTORY_RBAC}"
rm -f ${DIRECTORY_RBAC}/horsprod/*.csv

echo "Creating ${DIRECTORY_RBAC}/horsprod/dtr.csv"
export ID_APPLICATION_DOCKER
envsubst < ${DIRECTORY_TEMPLATE}/horsprod/dtr.csv.template > ${DIRECTORY_RBAC}/horsprod/dtr.csv

echo "Creating ${DIRECTORY_RBAC}/horsprod/kubernetes_namespaces.csv"
for ENV in ${LIST_ENVS_HORSPROD} ; do
	export ID_APPLICATION_DOCKER ENV
	envsubst < ${DIRECTORY_TEMPLATE}/horsprod/kubernetes_namespaces.csv.template >> ${DIRECTORY_RBAC}/horsprod/kubernetes_namespaces.csv
done

echo "Creating ${DIRECTORY_RBAC}/horsprod/teams_ucp.csv"
for ENV in ${LIST_ENVS_HORSPROD} ; do
	export ID_APPLICATION_DOCKER ENV
	envsubst < ${DIRECTORY_TEMPLATE}/horsprod/teams_ucp.csv.template >> ${DIRECTORY_RBAC}/horsprod/teams_ucp.csv
done

echo "Creating ${DIRECTORY_RBAC}/horsprod/teams_dtr.csv"
for NAMESPACE_DTR in ${LIST_NAMESPACES_DTR_HORSPROD} ; do
	export ID_APPLICATION_DOCKER NAMESPACE_DTR
	envsubst < ${DIRECTORY_TEMPLATE}/horsprod/teams_dtr.csv.template >> ${DIRECTORY_RBAC}/horsprod/teams_dtr.csv
done

echo
echo "Cluster prod"
ENV=prod
mkdir -p ${DIRECTORY_RBAC}/prod
echo "DEBUG : delete DIRECTORY_RBAC ${DIRECTORY_RBAC}"
rm -f ${DIRECTORY_RBAC}/prod/*.csv

echo "Creating ${DIRECTORY_RBAC}/prod/dtr.csv"
export ID_APPLICATION_DOCKER
envsubst < ${DIRECTORY_TEMPLATE}/prod/dtr.csv.template > ${DIRECTORY_RBAC}/prod/dtr.csv

echo "Creating ${DIRECTORY_RBAC}/prod/kubernetes_namespaces.csv"
export ID_APPLICATION_DOCKER
envsubst < ${DIRECTORY_TEMPLATE}/prod/kubernetes_namespaces.csv.template >> ${DIRECTORY_RBAC}/prod/kubernetes_namespaces.csv

echo "Creating ${DIRECTORY_RBAC}/prod/teams_ucp.csv"
export ID_APPLICATION_DOCKER
envsubst < ${DIRECTORY_TEMPLATE}/prod/teams_ucp.csv.template >> ${DIRECTORY_RBAC}/prod/teams_ucp.csv


echo "Creating ${DIRECTORY_RBAC}/prod/teams_dtr.csv"
export ID_APPLICATION_DOCKER NAMESPACE_DTR
envsubst < ${DIRECTORY_TEMPLATE}/prod/teams_dtr.csv.template >> ${DIRECTORY_RBAC}/prod/teams_dtr.csv

echo
echo "Please review files"
echo "To apply RBAC : ./apply_rbac.sh cluster_horsprod.properties ${ID_APPLICATION_DOCKER} ${DIRECTORY_RBAC}/horsprod"
echo
echo "To apply RBAC : ./apply_rbac.sh cluster_prod.properties ${ID_APPLICATION_DOCKER} ${DIRECTORY_RBAC}/prod"
exit 0

