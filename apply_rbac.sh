#!/bin/bash

if [ $# -ne 3 ] ; then
	echo "usage : $0 cluster.properties ID_APPLICATION_DOCKER DIRECTORY_RBAC"
	exit 1
fi
CLUSTER_PROPERTIES=$1
ID_APPLICATION_DOCKER=$2
DIRECTORY_RBAC=$3
DIR_BUNDLE="/tmp/bundle"


if [ ! -f "${CLUSTER_PROPERTIES}" ] ; then
	echo "File ${CLUSTER_PROPERTIES} does not exist"
	exit 1
fi
source ${CLUSTER_PROPERTIES}

if [ ! -f ${DIRECTORY_RBAC}/dtr.csv ] ; then
	echo "error dtr.csv is missing"
	exit 1
fi
if [ ! -f ${DIRECTORY_RBAC}/kubernetes_namespaces.csv ] ; then
	echo "error kubernetes_namespaces.csv is missing"
	exit 1
fi
if [ ! -f ${DIRECTORY_RBAC}/teams_ucp.csv ] ; then
	echo "error teams.csv is missing"
	exit 1
fi
if [ ! -f ${DIRECTORY_RBAC}/teams_dtr.csv ] ; then
	echo "error teams.csv is missing"
	exit 1
fi

if [ "${ID_APPLICATION_DOCKER}" = "" ] ; then
	echo "ERROR"
	exit 1
fi

if [ "${UCP_PASSWORD}" = "" ] ; then
	echo "Enter password for user ${UCP_USERNAME} :"
	read -s UCP_PASSWORD
fi
AUTHTOKEN=$(curl -sk -d '{"username":"'${UCP_USERNAME}'","password":"'${UCP_PASSWORD}'"}' https://${UCP_URL}/auth/login | jq -r .auth_token)
[[ "${AUTHTOKEN}" = "null" ]] && echo "Invalid token. Verify username/password" && exit 1

echo "Getting user bundle..."
rm -rf ${DIR_BUNDLE}
mkdir -p ${DIR_BUNDLE}
curl -k -H "Authorization: Bearer $AUTHTOKEN" https://${UCP_URL}/api/clientbundle -o ${DIR_BUNDLE}/bundle.zip 2>/dev/null
unzip -o ${DIR_BUNDLE}/bundle.zip -d $DIR_BUNDLE >/dev/null
echo "Sourcing bundle..."
cd ${DIR_BUNDLE} && source env.sh && cd -

if ! kubectl version >/dev/null 2>&1 ; then echo "Error getting Kubernetes version. Is bundle loaded ?" ; exit 1; fi

function api_docker_get {
	API=$*
	curl -sk -H "Authorization: Bearer $AUTHTOKEN" https://${UCP_URL}${API}
}
function api_docker_post {
	API=$*
	curl -sk -X POST -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Bearer $AUTHTOKEN" https://${UCP_URL}${API}
}
function api_docker_put {
	API=$*
	curl -sk -X PUT -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Bearer $AUTHTOKEN" https://${UCP_URL}${API}
}
function api_docker_del {
	API=$*
	curl -sk -X DELETE -H 'Accept: application/json' -H "Authorization: Bearer $AUTHTOKEN" https://${UCP_URL}${API}
}

function create_organization {
	ORGANIZATION=$1
	api_docker_post /accounts/ -d '{"name":"'${ORGANIZATION}'","isOrg":true}'
}

function create_namespace_kube {
	NAMESPACE_NAME=$1
	CMDB=$2
	ENVIRONMENT=$3
	POD_LIMIT=$4
	REQUEST_CPU=$5
	REQUEST_MEMORY=$6
	LIMIT_CPU=$7
	LIMIT_MEMORY=$8
	export NAMESPACE_NAME CMDB ENVIRONMENT POD_LIMIT REQUEST_CPU REQUEST_MEMORY LIMIT_CPU LIMIT_MEMORY
	envsubst < ./rbac/template/namespace/00-ns.yml.template | kubectl apply -f -
	envsubst < ./rbac/template/namespace/01-quota.yml.template | kubectl apply -f -
	envsubst < ./rbac/template/namespace/02-serviceaccount.yml.template | kubectl apply -f -
	envsubst < ./rbac/template/namespace/03-networkpolicy_denyall.yml.template | kubectl apply -f -
	envsubst < ./rbac/template/namespace/04-networkpolicy_allowfrominfra.yml.template | kubectl apply -f -

}

function create_team {
	ORGANIZATION=$1
	TEAM=$2
	GROUP_DN=$3
	K8S_ROLE=$4
	K8S_NAMESPACE=$5
	api_docker_post /accounts/${ORGANIZATION}/teams -d '{"name":"'${TEAM}'","description":"'${K8S_ROLE}'-->'${K8S_NAMESPACE}'"}'
	api_docker_put /accounts/${ORGANIZATION}/teams/${TEAM}/memberSyncConfig -d '{"enableSync":true,"groupDN":"'${GROUP_DN}'","groupMemberAttr":"member","searchBaseDN":"","searchFilter":"","searchScopeSubtree":false,"selectGroupMembers":true}'
}

function create_repo {
	ORGANIZATION=$1
	REPO=$2
	IMMUTABLE=$3
	SCAN_ON_PUSH=$4
	TAG_LIMIT=$5
	VISIBILITY=$6
	api_docker_post /repositories/${ORGANIZATION} -d '{"name":"'${REPO}'","enableManifestLists":"false","immutableTags":"'${IMMUTABLE}'","scanOnPush":"'${SCAN_ON_PUSH}'","tagLimit":"'${TAG_LIMIT}'","visibility":"'${VISIBILITY}'"}'
	
}

function grant_dtr_org_owner {
	ORGANIZATION=$1
	TEAM=$2
	curl -k -u ${UCP_USERNAME}:${UCP_PASSWORD} -X PUT -H 'Accept: application/json' -H 'Content-Type: application/json' https://${DTR_URL}/api/v0/repositoryNamespaces/${ORGANIZATION}/teamAccess/${TEAM}  -d '{ "accessLevel": "admin"}'
}

function create_rb_team_namespace {
	ORGANIZATION=$1
	TEAM_TMP=$2
	ROLE=$3
	NAMESPACE=$4
	TEAM=${ORGANIZATION}:${TEAM_TMP}
	export ROLE TEAM NAMESPACE
	envsubst < ./rbac/template/namespace/05-rolebinding.yml.template | kubectl apply -f -
}

echo "################################################################"
echo "##### KUBERNETES CLUSTERROLES #######"
echo "################################################################"
echo "#create kube ClusterRoles..."
for ROLE in ./rbac/template/role/* ; do
	echo "#kubectl apply -f ${ROLE}"
	kubectl apply -f ${ROLE}
done

echo
echo "################################################################"
echo "##### KUBERNETES NAMESPACES #######"
echo "################################################################"
egrep -v "^#" ${DIRECTORY_RBAC}/kubernetes_namespaces.csv | while IFS=";" read KUBE_NAMESPACE KUBERNETES_ENV KUBERNETES_POD_LIMIT KUBERNETES_REQUEST_CPU KUBERNETES_REQUEST_MEMORY KUBERNETES_LIMIT_CPU KUBERNETES_LIMIT_MEMORY ; do
	echo "Creating Kubernetes namespace ${KUBE_NAMESPACE}..."
	echo create_namespace_kube ${KUBE_NAMESPACE} ${ID_APPLICATION_DOCKER} ${KUBERNETES_ENV} ${KUBERNETES_POD_LIMIT} ${KUBERNETES_REQUEST_CPU} ${KUBERNETES_REQUEST_MEMORY} ${KUBERNETES_LIMIT_CPU} ${KUBERNETES_LIMIT_MEMORY}
	create_namespace_kube ${KUBE_NAMESPACE} ${ID_APPLICATION_DOCKER} ${KUBERNETES_ENV} ${KUBERNETES_POD_LIMIT} ${KUBERNETES_REQUEST_CPU} ${KUBERNETES_REQUEST_MEMORY} ${KUBERNETES_LIMIT_CPU} ${KUBERNETES_LIMIT_MEMORY}
done

echo kubectl get ns -l cmdb=${ID_APPLICATION_DOCKER}
kubectl get ns -l cmdb=${ID_APPLICATION_DOCKER}

echo
echo 
echo "################################################################"
echo "##### ORGANIZATION / TEAMS #######"
echo "################################################################"
echo "Creating UCP Organization..."
ORGANIZATION_NAME=${ID_APPLICATION_DOCKER}

echo "Organisation=${ORGANIZATION_NAME}"


echo "DEBUG : del org"
api_docker_del /accounts/${ORGANIZATION_NAME}

echo "#create_organization ${ORGANIZATION_NAME}"
create_organization ${ORGANIZATION_NAME}

egrep -v "^#" ${DIRECTORY_RBAC}/teams_ucp.csv | while IFS=";" read ORGANIZATION_NAME TEAM_NAME LDAP_GROUP KUBE_ROLE KUBE_NAMESPACE ; do
	echo
	echo 
	echo "#### Creating UCP Team ${ORGANIZATION_NAME}/${TEAM_NAME}... ####"
	echo "#create_team ${ORGANIZATION_NAME} ${TEAM_NAME} ${LDAP_GROUP} ${KUBE_ROLE} ${KUBE_NAMESPACE}"
	create_team ${ORGANIZATION_NAME} ${TEAM_NAME} ${LDAP_GROUP} ${KUBE_ROLE} ${KUBE_NAMESPACE}

	echo
	echo
	echo "#### Creating RoleBindings Teams<-->Namespaces... ####"
	echo "#create_rb_team_namespace ${ORGANIZATION_NAME} ${TEAM_NAME} ${KUBE_ROLE} ${KUBE_NAMESPACE}"
	create_rb_team_namespace ${ORGANIZATION_NAME} ${TEAM_NAME} ${KUBE_ROLE} ${KUBE_NAMESPACE}
done

echo
echo
echo "#### Trigger ldap sync... ####"
api_docker_post /enzi/v0/jobs -d '{"action":"ldap-sync"}'

echo
echo
echo "################################################################"
echo "##### DTR #######"
echo "################################################################"
echo "Creating DTR namespaces..."

egrep -v "^#" ${DIRECTORY_RBAC}/dtr.csv | while IFS=";"IFS=";"  read REPO_DTR ; do
	# A DTR Namespace is just a UCP Organization
	echo "#create_organization ${REPO_DTR}"
	create_organization ${REPO_DTR}
done

echo "Creating DTR teams..."
egrep -v "^#" ${DIRECTORY_RBAC}/teams_dtr.csv | while IFS=";" read ORGANIZATION_NAME TEAM_NAME LDAP_GROUP ROLE NAMESPACE; do
	echo
	echo 
	echo "#### Creating UCP Team ${ORGANIZATION_NAME}/${TEAM_NAME}... ####"
	echo "#create_team ${ORGANIZATION_NAME} ${TEAM_NAME} ${LDAP_GROUP} ${ROLE} ${NAMESPACE}"
	create_team ${ORGANIZATION_NAME} ${TEAM_NAME} ${LDAP_GROUP} ${ROLE} ${NAMESPACE}

	echo
	echo
	echo "#### Granting Team to Org Owner in DTR... ####"
	echo "#grant_dtr_org_owner ${ORGANIZATION_NAME} ${TEAM_NAME}"
	grant_dtr_org_owner ${ORGANIZATION_NAME} ${TEAM_NAME}
done

#https://imti.co/team-kubernetes-remote-access/
#https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/
#https://gist.github.com/mreferre/6aae10ddc313dd28b72bdc9961949978

rm -rf ${DIR_BUNDLE}
