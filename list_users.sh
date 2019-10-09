#!/bin/sh

# Fill in UCP information
UCP_FQDN='ucp.pac-test.dockerps.io'
UCP_USERNAME='admin'
UCP_PASSWORD='dockeradmin'

# Get token from UCP to use for API requests
UCP_TOKEN=$(curl \
  --data '{"username":"'${UCP_USERNAME}'","password":"'${UCP_PASSWORD}'"}' \
  --insecure \
  --request POST \
  --silent \
  --url https://${UCP_FQDN}/auth/login | jq -r .auth_token)

ORGANIZATIONS=$(curl \
  --header "authorization: Bearer ${UCP_TOKEN}" \
  --header 'content-type: application/json' \
  --insecure \
  --request GET \
  --silent \
  --url "https://${UCP_FQDN}/accounts?filter=orgs&limit=1000"  | jq --raw-output '.accounts[].name' )

# Loop through each organization
for ORGANIZATION in ${ORGANIZATIONS}
do
  # Write out the organization's name
  echo "├── ${ORGANIZATION}"

  TEAMS=$(curl \
  --header "authorization: Bearer ${UCP_TOKEN}" \
  --header 'content-type: application/json' \
  --insecure \
  --request GET \
  --silent \
  --url "https://${UCP_FQDN}/accounts/${ORGANIZATION}/teams"  | jq --raw-output '.teams[].name' )

  # Indent team names underneath organization name
  for TEAM in ${TEAMS}
  do
    echo "    └── ${TEAM}"
  done

  # Get members for each team
  MEMBERS=$(curl \
  --header "authorization: Bearer ${UCP_TOKEN}" \
  --header 'content-type: application/json' \
  --insecure \
  --request GET \
  --silent \
  --url "https://${UCP_FQDN}/accounts/${ORGANIZATION}/teams/${TEAM}/members"  | jq --raw-output '.members[].member.name' )

  # Indent and writeout each member on a new line
  for MEMBER in ${MEMBERS}
  do
    echo "        └── ${MEMBER}"
  done

done
