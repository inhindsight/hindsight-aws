#!/usr/bin/env bash

set -eo pipefail

function check_dependencies {
    for dep in aws kubectl eksctl helm jq; do
        type $dep 1> /dev/null
    done
}

function template_bucket {
    aws cloudformation deploy \
        --no-fail-on-empty-changeset \
        --stack-name hindsight-templates-${ENVIRONMENT_NAME} \
        --template-file ./aws/cf-bucket.yaml \
        --parameter-overrides BucketName=${TEMPLATE_BUCKET}
}

function hindsight_stack_package {
    aws cloudformation package \
        --template-file ./aws/hindsight.yaml \
        --s3-bucket ${TEMPLATE_BUCKET} \
        --output-template-file ./.out/${STACK_NAME}.yaml
}

function hindsight_stack_deploy {
    aws cloudformation deploy $@ \
        --template-file ./.out/${STACK_NAME}.yaml \
        --stack-name ${STACK_NAME} \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameter-overrides \
            EnvironmentName=${ENVIRONMENT_NAME} \
            DataBucketPrefix=${BUCKET_PREFIX}
}

function write_kubeconfig {
    eksctl utils write-kubeconfig hindsight-kubernetes-${ENVIRONMENT_NAME}
}

function get {
    local -r key="${1}"

    aws cloudformation describe-stacks \
        | jq -r ".Stacks[] | select(.StackName == \"${STACK_NAME}\") | .Outputs[] | select(.OutputKey == \"${key}\") | .OutputValue"
}

function iam_mapping {
    local -r node=$(get KubeNodeRole)
    local -r user=$(get KubeUserRole)

    helm template aws ./helm --set aws.role.node="${node}",aws.role.user="${user}" \
        | kubectl apply -n kube-system -f -
}

if [[ "${1}" == "-h" || "${1}" == "--help" ]]; then
    echo "Usage: ${0} [STACK_PREFIX] [BUCKET_PREFIX] [ENVIRONMENT] <cf_flags>"
    echo ""
    echo "EXAMPLE:"
    echo "    $ ${0} my-stack my-bucket dev --no-execute-changeset"
    exit 0
fi

declare -r STACK_PREFIX="${1:?Stack prefix required.}"
declare -r BUCKET_PREFIX="${2:?Bucket prefix required.}"
declare -r ENVIRONMENT_NAME="${3:?Environment name required.}"
shift 3

declare -r STACK_NAME="${STACK_PREFIX}-${ENVIRONMENT_NAME}"
declare -r TEMPLATE_BUCKET="${STACK_NAME}-templates"

check_dependencies
template_bucket
hindsight_stack_package
hindsight_stack_deploy "${@}"
write_kubeconfig
iam_mapping
