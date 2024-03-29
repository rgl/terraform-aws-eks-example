# About

[![Lint](https://github.com/rgl/terraform-aws-eks-example/actions/workflows/lint.yml/badge.svg)](https://github.com/rgl/terraform-aws-eks-example/actions/workflows/lint.yml)

This creates an example kubernetes cluster hosted in the [AWS Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks/) using a terraform program.

This will:

* Create an Elastic Kubernetes Service (EKS)-based Kubernetes cluster.
  * Enable the [VPC CNI cluster addon](https://docs.aws.amazon.com/eks/latest/userguide/managing-vpc-cni.html).
* Create the Elastic Container Registry (ECR) repositories declared on the
  [`images` local variable](ecr.tf), and upload the corresponding container
  images.
* Demonstrate how to manually deploy a Kubernetes application.
  * Expose as a Kubernetes `LoadBalancer` `Service`. Note that this results in the creation of an [EC2 Classic Load Balancer (CLB)](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/introduction.html).

# Usage (on a Ubuntu Desktop)

Install the dependencies:

* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
* [Terraform](https://www.terraform.io/downloads.html).
* [kubectl](https://kubernetes.io/docs/tasks/tools/).
* [Docker](https://docs.docker.com/engine/install/).
* [Crane](https://github.com/google/go-containerregistry/releases).

Set the AWS Account credentials using SSO:

```bash
# set the environment variables to use a specific profile.
# e.g. use the pattern <aws-sso-session-name>-<aws-account-name>-<aws-account-role>-<aws-account-id>
export AWS_PROFILE=example-dev-AdministratorAccess-123456
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_DEFAULT_REGION
# set the account credentials.
# see https://docs.aws.amazon.com/cli/latest/userguide/sso-configure-profile-token.html#sso-configure-profile-token-auto-sso
aws configure sso
# dump the configured profile and sso-session.
cat ~/.aws/config
# show the user, user amazon resource name (arn), and the account id, of the
# profile set in the AWS_PROFILE environment variable.
aws sts get-caller-identity
```

Or, set the AWS Account credentials using an Access Key:

```bash
# set the account credentials.
# NB get these from your aws account iam console.
#    see Managing access keys (console) at
#        https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey
export AWS_ACCESS_KEY_ID='TODO'
export AWS_SECRET_ACCESS_KEY='TODO'
unset AWS_PROFILE
# set the default region.
export AWS_DEFAULT_REGION='eu-west-1'
# show the user, user amazon resource name (arn), and the account id.
aws sts get-caller-identity
```

Review `main.tf`.

Initialize terraform:

```bash
make terraform-init
```

Launch the example:

```bash
make terraform-apply
```

Show the terraform state:

```bash
make terraform-state-list
make terraform-show
```

Show the [OpenID Connect Discovery Document](https://openid.net/specs/openid-connect-discovery-1_0.html) (aka OpenID Connect Configuration):

```bash
wget -qO- "$(terraform output -raw kubernetes_oidc_configuration_url)" \
  | jq
```

Access the EKS cluster:

```bash
export KUBECONFIG="$PWD/kubeconfig.yml"
kubectl cluster-info
kubectl get nodes -o wide
```

If for some reason the `kubeconfig.yml` is stale, you can re-created it, either
with `make terraform-apply`, or:

```bash
rm "$KUBECONFIG"
aws eks update-kubeconfig \
  --region "$(terraform output -raw kubernetes_region)" \
  --name "$(terraform output -raw kubernetes_cluster_name)"
```

Log in the container registry:

**NB** You are logging in at the registry level. You are not logging in at the
repository level.

```bash
aws ecr get-login-password \
  --region "$(terraform output -raw registry_region)" \
  | docker login \
      --username AWS \
      --password-stdin \
      "$(terraform output -raw registry_domain)"
```

**NB** This saves the credentials in the `~/.docker/config.json` local file.

Show the example image manifest that was uploaded into the created container
image repository:

```bash
image="$(terraform output --json images | jq -r .example)"
crane manifest "$image" | jq .
```

Log out the container registry:

```bash
docker logout \
  "$(terraform output -raw registry_domain)"
```

Launch the example application, using the image that was uploaded into the
created image repository:

```bash
sed -E "s,ruilopes/example-docker-buildx-go:.+,$image,g" example-app.yml \
  | kubectl apply -f -
kubectl rollout status daemonset/example
kubectl get pods,services
```

Access the service from a [kubectl port-forward local port](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/):

```bash
kubectl port-forward service/example 6789:80 &
sleep 3 && printf '\n\n'
wget -qO- http://localhost:6789
kill %1 && sleep 3
```

Access the service from the Internet:

```bash
example_domain="$(kubectl get service/example -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
example_url="http://$example_domain"
echo "example service url: $example_url"
# wait for the domain to resolve.
while [ -z "$(dig +short "$example_domain")" ]; do sleep 5; done && dig "$example_domain"
# finally, access the service.
wget -qO- "$example_url"
```

Destroy the example application:

```bash
sed -E "s,ruilopes/example-docker-buildx-go:.+,$image,g" example-app.yml \
  | kubectl delete -f -
kubectl get pods,services
```

Destroy the example:

```bash
make terraform-destroy
```

**NB** For some unknown reason, terraform shows the following Warning message. If you known how to fix it, please let me known!

```
╷
│ Warning: EC2 Default Network ACL (acl-004fd974909c20839) not deleted, removing from state
│
│
╵
```

# Notes

* OpenID Connect Provider for EKS (aka [Enable IAM Roles for Service Accounts (IRSA)](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/setting-up-enable-IAM.html)) is enabled.
  * a [aws_iam_openid_connect_provider resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) is created.
* The EKS nodes virtual machines boot from a customizable Amazon Machine Image (AMI).
  * This example uses the Amazon Linux 2 AMI.
  * The official AMIs source code is available at the [Amazon EKS AMI awslabs/amazon-eks-ami repository](https://github.com/awslabs/amazon-eks-ami).

# References

* [Environment variables to configure the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html)
* [Token provider configuration with automatic authentication refresh for AWS IAM Identity Center](https://docs.aws.amazon.com/cli/latest/userguide/sso-configure-profile-token.html) (SSO)
* [Managing access keys (console)](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey)
* [AWS General Reference](https://docs.aws.amazon.com/general/latest/gr/Welcome.html)
  * [Amazon Resource Names (ARNs)](https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html)
* [Amazon ECR private registry](https://docs.aws.amazon.com/AmazonECR/latest/userguide/Registries.html)
  * [Private registry authentication](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html)
* [Network load balancing on Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html)
* [Amazon EKS add-ons](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html)
* [Amazon EKS VPC-CNI](https://github.com/aws/amazon-vpc-cni-k8s)
* [EKS Workshop](https://www.eksworkshop.com)
  * [Using Terraform](https://www.eksworkshop.com/docs/introduction/setup/your-account/using-terraform)
    * [aws-samples/eks-workshop-v2 example repository](https://github.com/aws-samples/eks-workshop-v2/tree/main/cluster/terraform)
* [Official Amazon EKS AMI awslabs/amazon-eks-ami repository](https://github.com/awslabs/amazon-eks-ami)
