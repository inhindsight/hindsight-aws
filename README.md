# hindsight-aws

AWS infrastructure provisioning for Hindsight

## Usage

Run `deploy.sh` to provision infrastructure in AWS:

```bash
./deploy.sh $StackName $BucketName $EnvironmentName
```

`$StackName` and `$BucketName` will be suffixed by `$EnvironmentName` when naming resources.

### CloudFormation

Running `deploy.sh` provisions an S3 bucket for storing the CloudFormation templates used to
create Hindsight infrastructure. This template bucket is versioned to allow you to see changes
made to your templates over time.

### EKS

Running `deploy.sh` will provision an EKS instance with multiple roles attached. An `iamidentitymapping`
will be applied to the `aws-auth` ConfigMap in your Kubernetes instance. Anyone able to assume the
`hindsight-kubernetes-user-role-$EnvironmentName` role will have access to your EKS instance.

### Credentials

Running `deploy.sh` generates passwords for all RDS databases and stores them in SecretsManager with other
database credentials. Password values are accessible in SecretsManager under `hindsight-$HindsightService-$EnvironmentName`.

## Installation

Running `deploy.sh` requires `awscli`, `kubectl`, `eksctl`, `helm`, and `jq`.
