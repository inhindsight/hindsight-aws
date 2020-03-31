# hindsight-aws

## Usage

Run `./deploy.sh` to create Hindsight's underlying infrastructure in AWS. It will create a cloud formation stack named $StackPrefix-$EnvironmentName and an s3 bucket named $BucketPrefix-$EnvironmentName

```bash
./deploy.sh foo-stack-prefix foo-bucket-prefix environmentName
```

Running the script will deploy a CloudFormation stack and apply an `iamidentitymapping` to
the `aws-auth` ConfigMap in Kubernetes. Anyone who can assume the `hindsight-user-role` will
be able to work with your EKS instance.

## Installation

At a minimum, you will need `awscli`, `kubectl`, and `helm`.

Running our `./deploy.sh` script also requires `jq`.
