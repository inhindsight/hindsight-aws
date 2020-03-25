#!/usr/bin/env bash

set -eo pipefail

function deploy {

    local -r db_password=$(openssl rand 24 -hex)
    local -r graf_password=$(openssl rand 24 -hex)

    aws cloudformation deploy \
        --stack-name=${STACK_PREFIX}-${ENVIRONMENT_NAME} \
        --template-file hindsight.yaml \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameter-overrides \
            DataBucketPrefix=${BUCKET_PREFIX} \
            EnvironmentName=${ENVIRONMENT_NAME} \
            DbPassword=${db_password} \
            GrafanaPassword=${graf_password} \
        "${@}"
}

function get_output {
    local -r key="${1}"

    export AWS_PROFILE=${PROFILE_NAME}

    aws cloudformation describe-stacks \
        | jq -r ".Stacks[] | select(.StackName == \"${STACK_PREFIX}-${ENVIRONMENT_NAME}\") | .Outputs[] | select(.OutputKey == \"${key}\") | .OutputValue"
}

function iam_mapping {
    local -r node=$(get_output NodeRole)
    local -r user=$(get_output UserRole)

    if [[ $(grep -v "${user}" ~/.aws/config > /dev/null) ]]; then
        echo "Adding hindsight eks profile to aws config"
        echo -e "\n[profile hindsight-${ENVIRONMENT_NAME}]\nrole_arn=${user}\nsource_profile=${PROFILE_NAME}" >> ~/.aws/config
    else
        echo "Skipping profile append; hindsight eks profile already present"
    fi

    export AWS_PROFILE="hindsight-${ENVIRONMENT_NAME}"

    helm template aws ./helm --set aws.role.node="${node}",aws.role.user="${user}" | kubectl apply -n kube-system -f -
}

function get_kubeconfig {
    eksctl utils write-kubeconfig hindsight-kubernetes-${ENVIRONMENT_NAME} --kubeconfig="${HOME}/.kube/hindsight_${ENVIRONMENT}"
}

function check_dependencies {
    type eksctl 1> /dev/null
    type openssl 1> /dev/null
    type helm 1> /dev/null
    type jq 1> /dev/null
}

if [[ $1 == "-h" || $1 == "--help" ]]; then
    echo "Usage: ./deploy.sh [STACK_PREFIX] [BUCKET_PREFIX] [ENVIRONMENT_NAME] [PROFILE_NAME] [cf_flags]"
    exit 0
fi

declare -r STACK_PREFIX="${1:?Stack prefix required.}"
shift

declare -r BUCKET_PREFIX="${1:?Bucket prefix required.}"
shift

declare -r ENVIRONMENT_NAME="${1:?Environment name required.}"
shift

declare -r PROFILE_NAME="${1:?AWS user profile name required.}"
shift

check_dependencies
deploy $@
get_kubeconfig
iam_mapping
