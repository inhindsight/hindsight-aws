#!/usr/bin/env bash

set -eo pipefail

function deploy {
    local -r bucket="${1:?Bucket name required.}"
    shift

    aws cloudformation deploy \
        --stack-name=${STACK_NAME} \
        --template-file hindsight.yaml \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameter-overrides DataBucketName=${bucket} \
        "${@}"
}

function get_output {
    local -r key="${1}"

    aws cloudformation describe-stacks \
        | jq -r ".Stacks[] | select(.StackName == \"${STACK_NAME}\") | .Outputs[] | select(.OutputKey == \"${key}\") | .OutputValue"
}

function iam_mapping {
    local -r node=$(get_output NodeRole)
    local -r user=$(get_output UserRole)

    helm template aws ./helm --set aws.role.node="${node}",aws.role.user="${user}" | kubectl apply -n kube-system -f -
}

if [[ $1 == "-h" || $1 == "--help" ]]; then
    echo "Usage: ./deploy.sh [STACK_NAME] [BUCKET_NAME] [cf_flags]"
    exit 0
fi

declare -r STACK_NAME="${1:?Stack name required.}"
shift

deploy $@
iam_mapping
