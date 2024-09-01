# About

[![Lint](https://github.com/rgl/terraform-aws-eks-example/actions/workflows/lint.yml/badge.svg)](https://github.com/rgl/terraform-aws-eks-example/actions/workflows/lint.yml)

This creates an example kubernetes cluster hosted in the [AWS Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks/) using a terraform program.

This will:

* Create an Elastic Kubernetes Service (EKS)-based Kubernetes cluster.
  * Use the [Bottlerocket OS](https://aws.amazon.com/bottlerocket/).
  * Enable the [VPC CNI cluster add-on](https://docs.aws.amazon.com/eks/latest/userguide/managing-vpc-cni.html).
  * Enable the [EBS CSI cluster add-on](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html).
  * Install [external-dns](https://github.com/kubernetes-sigs/external-dns).
    * Manages DNS Resource Records.
  * Install [cert-manager](https://github.com/cert-manager/cert-manager).
    * Manages TLS certificate.
  * Install [trust-manager](https://github.com/cert-manager/trust-manager).
    * Manages TLS CA certificate bundles.
  * Install [reloader](https://github.com/stakater/reloader).
    * Reloads (restarts) pods when their configmaps or secrets change.
  * Install [Gitea](https://github.com/go-gitea/gitea).
    * Manages git repositories.
  * Install [Argo CD](https://github.com/argoproj/argo-cd).
    * Manages continuous deployments.
* Create the Elastic Container Registry (ECR) repositories declared on the
  [`images` local variable](ecr.tf), and upload the corresponding container
  images.
* Create a public DNS Zone using [Amazon Route 53](https://aws.amazon.com/route53/).
  * Note that you need to configure the parent DNS Zone to delegate to this DNS Zone name servers.
  * Use [external-dns](https://github.com/kubernetes-sigs/external-dns) to create the Ingress DNS Resource Records in the DNS Zone.
* Demonstrate how to automatically deploy the [`example-app` workload](example-app.tf).
  * Expose as a Kubernetes `Ingress` `Service`.
    * Use a sub-domain in the DNS Zone.
    * Use a public Certificate managed by [Amazon Certificate Manager](https://aws.amazon.com/certificate-manager/) and issued by the public [Amazon Root CA](https://www.amazontrust.com/repository/).
    * Note that this results in the creation of an [EC2 Application Load Balancer (ALB)](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html).

# Usage (on a Ubuntu Desktop)

Install the dependencies:

* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
* [Terraform](https://www.terraform.io/downloads.html).
* [kubectl](https://kubernetes.io/docs/tasks/tools/).
* [Docker](https://docs.docker.com/engine/install/).
* [Crane](https://github.com/google/go-containerregistry/releases).
* [argocd cli](https://argo-cd.readthedocs.io/en/stable/getting_started/#2-download-argo-cd-cli).

Set the AWS Account credentials using SSO, e.g.:

```bash
# set the account credentials.
# NB the aws cli stores these at ~/.aws/config.
# NB this is equivalent to manually configuring SSO using aws configure sso.
# see https://docs.aws.amazon.com/cli/latest/userguide/sso-configure-profile-token.html#sso-configure-profile-token-manual
# see https://docs.aws.amazon.com/cli/latest/userguide/sso-configure-profile-token.html#sso-configure-profile-token-auto-sso
cat >secrets-example.sh <<'EOF'
# set the environment variables to use a specific profile.
# NB use aws configure sso to configure these manually.
# e.g. use the pattern <aws-sso-session>-<aws-account-id>-<aws-role-name>
export aws_sso_session='example'
export aws_sso_start_url='https://example.awsapps.com/start'
export aws_sso_region='eu-west-1'
export aws_sso_account_id='123456'
export aws_sso_role_name='AdministratorAccess'
export AWS_PROFILE="$aws_sso_session-$aws_sso_account_id-$aws_sso_role_name"
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_DEFAULT_REGION
# configure the ~/.aws/config file.
# NB unfortunately, I did not find a way to create the [sso-session] section
#    inside the ~/.aws/config file using the aws cli. so, instead, manage that
#    file using python.
python3 <<'PY_EOF'
import configparser
import os
aws_sso_session = os.getenv('aws_sso_session')
aws_sso_start_url = os.getenv('aws_sso_start_url')
aws_sso_region = os.getenv('aws_sso_region')
aws_sso_account_id = os.getenv('aws_sso_account_id')
aws_sso_role_name = os.getenv('aws_sso_role_name')
aws_profile = os.getenv('AWS_PROFILE')
config = configparser.ConfigParser()
aws_config_directory_path = os.path.expanduser('~/.aws')
aws_config_path = os.path.join(aws_config_directory_path, 'config')
if os.path.exists(aws_config_path):
  config.read(aws_config_path)
config[f'sso-session {aws_sso_session}'] = {
  'sso_start_url': aws_sso_start_url,
  'sso_region': aws_sso_region,
  'sso_registration_scopes': 'sso:account:access',
}
config[f'profile {aws_profile}'] = {
  'sso_session': aws_sso_session,
  'sso_account_id': aws_sso_account_id,
  'sso_role_name': aws_sso_role_name,
  'region': aws_sso_region,
}
os.makedirs(aws_config_directory_path, mode=0o700, exist_ok=True)
with open(aws_config_path, 'w') as f:
  config.write(f)
PY_EOF
unset aws_sso_start_url
unset aws_sso_region
unset aws_sso_session
unset aws_sso_account_id
unset aws_sso_role_name
# show the user, user amazon resource name (arn), and the account id, of the
# profile set in the AWS_PROFILE environment variable.
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  aws sso login
fi
aws sts get-caller-identity
EOF
```

Or, set the AWS Account credentials using an Access Key, e.g.:

```bash
# set the account credentials.
# NB get these from your aws account iam console.
#    see Managing access keys (console) at
#        https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey
cat >secrets-example.sh <<'EOF'
export AWS_ACCESS_KEY_ID='TODO'
export AWS_SECRET_ACCESS_KEY='TODO'
unset AWS_PROFILE
# set the default region.
export AWS_DEFAULT_REGION='eu-west-1'
# show the user, user amazon resource name (arn), and the account id.
aws sts get-caller-identity
EOF
```

Load the secrets:

```bash
source secrets-example.sh
```

Review the variables inside the [`inputs.tf`](inputs.tf) file, and, at least,
modify the `ingress_domain` variable to a DNS Zone that is a child of a
DNS Zone that you control. The `ingress_domain` DNS Zone will be created by
this example. The DNS Zone will be hosted in the Amazon Route 53 DNS name
servers, e.g.:

```bash
cat >terraform.tfvars <<EOF
environment    = "dev"
project        = "aws-eks-example"
ingress_domain = "aws-eks-example-dev.example.test"
EOF
```

Initialize terraform:

```bash
make terraform-init
```

Launch the example:

```bash
rm -f terraform.log
make terraform-apply
```

The first launch will fail while trying to create the `aws_acm_certificate`
resource. You must delegate the DNS Zone, as described bellow, and then launch
the example again to finish the provisioning.

Show the ingress domain and the ingress DNS Zone name servers:

```bash
ingress_domain="$(terraform output -raw ingress_domain)"
ingress_domain_name_servers="$(
  terraform output -json ingress_domain_name_servers \
  | jq -r '.[]')"
printf "ingress_domain:\n\n$ingress_domain\n\n"
printf "ingress_domain_name_servers:\n\n$ingress_domain_name_servers\n\n"
```

Using your parent ingress domain DNS Registrar or DNS Hosting provider, delegate the `ingress_domain` DNS Zone to the returned `ingress_domain_name_servers` DNS name servers. For example, at the parent DNS Zone, add:

```plain
aws-eks-example-dev NS ns-123.awsdns-11.com.
aws-eks-example-dev NS ns-321.awsdns-34.net.
aws-eks-example-dev NS ns-456.awsdns-56.org.
aws-eks-example-dev NS ns-948.awsdns-65.co.uk.
```

Verify the delegation:

```bash
ingress_domain="$(terraform output -raw ingress_domain)"
ingress_domain_name_server="$(
  terraform output -json ingress_domain_name_servers | jq -r '.[0]')"
dig ns "$ingress_domain" "@$ingress_domain_name_server" # verify with amazon route 53 dns.
dig ns "$ingress_domain"                                # verify with your local resolver.
```

Launch the example again, this time, no error is expected:

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

Get the cluster `kubeconfig.yml` configuration file:

```bash
export KUBECONFIG="$PWD/kubeconfig.yml"
rm -f "$KUBECONFIG"
aws eks update-kubeconfig \
  --region "$(terraform output -raw kubernetes_region)" \
  --name "$(terraform output -raw kubernetes_cluster_name)"
```

Access the EKS cluster:

```bash
export KUBECONFIG="$PWD/kubeconfig.yml"
kubectl cluster-info
kubectl get nodes -o wide
kubectl get ingressclass
kubectl get storageclass
# NB notice that the ReclaimPolicy is Delete. this means that, when we delete a
#    PersistentVolumeClaim or PersistentVolume, the volume will be deleted from
#    the AWS account.
kubectl describe storageclass/gp2
kubectl describe storageclass/gp3
```

List the installed Helm chart releases:

```bash
helm list --all-namespaces
```

Show a helm release status, the user supplied values, all the values, and the
chart managed kubernetes resources:

```bash
helm -n external-dns status external-dns
helm -n external-dns get values external-dns
helm -n external-dns get values external-dns --all
helm -n external-dns get manifest external-dns
```

List all the running container images:

```bash
# see https://kubernetes.io/docs/tasks/access-application-cluster/list-all-running-container-images/
kubectl get pods --all-namespaces \
  -o jsonpath="{.items[*].spec['initContainers','containers'][*].image}" \
  | tr -s '[[:space:]]' '\n' \
  | sort --unique
```

It should be something like:

```bash
602401143452.dkr.ecr.eu-west-1.amazonaws.com/amazon/aws-network-policy-agent:v1.1.2-eksbuild.2
602401143452.dkr.ecr.eu-west-1.amazonaws.com/amazon-k8s-cni-init:v1.18.3-eksbuild.2
602401143452.dkr.ecr.eu-west-1.amazonaws.com/amazon-k8s-cni:v1.18.3-eksbuild.2
602401143452.dkr.ecr.eu-west-1.amazonaws.com/eks/aws-ebs-csi-driver:v1.34.0
602401143452.dkr.ecr.eu-west-1.amazonaws.com/eks/coredns:v1.11.1-eksbuild.8
602401143452.dkr.ecr.eu-west-1.amazonaws.com/eks/csi-attacher:v4.6.1-eks-1-30-10
602401143452.dkr.ecr.eu-west-1.amazonaws.com/eks/csi-node-driver-registrar:v2.11.0-eks-1-30-10
602401143452.dkr.ecr.eu-west-1.amazonaws.com/eks/csi-provisioner:v5.0.1-eks-1-30-10
602401143452.dkr.ecr.eu-west-1.amazonaws.com/eks/csi-resizer:v1.11.1-eks-1-30-10
602401143452.dkr.ecr.eu-west-1.amazonaws.com/eks/csi-snapshotter:v8.0.1-eks-1-30-12
602401143452.dkr.ecr.eu-west-1.amazonaws.com/eks/kube-proxy:v1.30.0-minimal-eksbuild.3
602401143452.dkr.ecr.eu-west-1.amazonaws.com/eks/livenessprobe:v2.13.0-eks-1-30-10
960774936715.dkr.ecr.eu-west-1.amazonaws.com/aws-eks-example-dev/example-app:v1.12.0
ghcr.io/dexidp/dex:v2.38.0
ghcr.io/stakater/reloader:v1.1.0
gitea/gitea:1.22.1-rootless
public.ecr.aws/docker/library/redis:7.2.4-alpine
public.ecr.aws/eks/aws-load-balancer-controller:v2.7.1
quay.io/argoproj/argocd:v2.12.3
quay.io/jetstack/cert-manager-cainjector:v1.15.3
quay.io/jetstack/cert-manager-controller:v1.15.3
quay.io/jetstack/cert-manager-package-debian:20210119.0
quay.io/jetstack/cert-manager-webhook:v1.15.3
quay.io/jetstack/trust-manager:v0.12.0
registry.k8s.io/external-dns/external-dns:v0.14.2
ruilopes/example-docker-buildx-go:v1.12.0
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
image="$(terraform output --json images | jq -r .example_app)"
crane manifest "$image" | jq .
```

Log out the container registry:

```bash
docker logout \
  "$(terraform output -raw registry_domain)"
```

Access the `example-app` service from a [kubectl port-forward local port](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/):

```bash
kubectl port-forward service/example-app 6789:80 &
sleep 3 && printf '\n\n'
wget -qO- http://localhost:6789
kill %1 && sleep 3
```

Access the `example-app` service from the Internet:

```bash
example_app_url="$(terraform output -raw example_app_url)"
example_app_domain="${example_app_url#https://}"
echo "example-app service url: $example_app_url"
# wait for the domain to resolve.
while [ -z "$(dig +short "$example_app_domain")" ]; do sleep 5; done && dig "$example_app_domain"
# finally, access the service.
wget -qO- "$example_app_url"
```

Access Gitea:

```bash
gitea_url="$(terraform output -raw gitea_url)"
gitea_password="$(terraform output -raw gitea_password)"
echo "gitea_url: $gitea_url"
echo "gitea_username: gitea"
echo "gitea_password: $gitea_password"
xdg-open "$gitea_url"
```

Access Argo CD:

```bash
argocd_url="$(terraform output -raw argocd_url)"
argocd_admin_password="$(
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \
    | base64 --decode)"
echo "argocd_url: $argocd_url"
echo "argocd_admin_password: $argocd_admin_password"
xdg-open "$argocd_url"
```

If the Argo CD UI is showing these kind of errors:

> Unable to load data: permission denied
> Unable to load data: error getting cached app managed resources: NOAUTH Authentication required.
> Unable to load data: error getting cached app managed resources: cache: key is missing
> Unable to load data: error getting cached app managed resources: InvalidSpecError: Application referencing project default which does not exist

Try restarting some of the Argo CD components, and after restarting them, the
Argo CD UI should start working after a few minutes (e.g. at the next sync
interval, which defaults to 3m):

```bash
kubectl -n argocd rollout restart statefulset argo-cd-argocd-application-controller
kubectl -n argocd rollout status statefulset argo-cd-argocd-application-controller --watch
kubectl -n argocd rollout restart deployment argo-cd-argocd-server
kubectl -n argocd rollout status deployment argo-cd-argocd-server --watch
```

Create the `example-argocd` repository:

```bash
ingress_domain="$(terraform output -raw ingress_domain)"
curl \
  --silent \
  --show-error \
  --fail-with-body \
  -u "gitea:$gitea_password" \
  -X POST \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "example-argocd",
    "private": true
  }' \
  "$gitea_url/api/v1/user/repos" \
  | jq
rm -rf tmp/example-argocd
git init tmp/example-argocd
pushd tmp/example-argocd
git branch -m main
cp -r ../../example-argocd/* .
git add .
git commit -m init
git remote add origin "$gitea_url/gitea/example-argocd.git"
git push -u origin main
popd
```

Create the `example` argocd application:

```bash
argocd_fqdn="${argocd_url#https://}"
argocd login \
  "$argocd_fqdn" \
  --grpc-web \
  --username admin \
  --password "$argocd_admin_password"
argocd cluster list
# NB if git repository was hosted outside of the cluster, we might have
#    needed to execute the following to trust the certificate.
#     argocd cert add-tls gitea.example.test --from "$SSL_CERT_FILE"
#     argocd cert list --cert-type https
# NB we have to access gitea thru the internal cluster service because the
#    external/ingress domains does not resolve inside the cluster.
argocd repo add \
  http://gitea-http.gitea.svc:3000/gitea/example-argocd.git \
  --grpc-web \
  --username gitea \
  --password "$gitea_password"
# NB it might not be advisable to configure a real application like this,
#    instead, the values should be in a file, in a git repository.
argocd app create \
  example \
  --dest-name in-cluster \
  --dest-namespace default \
  --project default \
  --auto-prune \
  --self-heal \
  --sync-policy automatic \
  --repo http://gitea-http.gitea.svc:3000/gitea/example-argocd.git \
  --path . \
  --values-literal-file <(cat <<EOF
ingressDomain: $(terraform output -raw ingress_domain)
replicas: 1
EOF
)
argocd app list
argocd app wait example --health --timeout 900
kubectl get crd | grep argoproj.io
kubectl -n argocd get applications
kubectl -n argocd get application/example -o yaml
```

Access the example application:

```bash
kubectl rollout status deployment/example
kubectl get ingresses,services,pods,deployments
example_fqdn="$(kubectl get ingress/example -o json | jq -r .spec.rules[0].host)"
example_url="http://$example_fqdn"
# wait for the domain to resolve.
while [ -z "$(dig +short "$example_fqdn")" ]; do sleep 5; done && dig "$example_fqdn"
# finally, access the application endpoint.
xdg-open "$example_url"
```

Modify the example argocd application, by modifying the number of replicas:

```bash
argocd app set example --helm-set replicas=5
argocd app wait example --health --timeout 900
```

Then go the Argo CD UI, and wait for it to eventually sync the example argocd
application, or click `Refresh` to sync it immediately.

Delete the example argocd application and repository:

```bash
argocd app delete \
  example \
  --wait \
  --yes
argocd repo rm \
  http://gitea-http.gitea.svc:3000/gitea/example-argocd.git
curl \
  --silent \
  --show-error \
  --fail-with-body \
  -u "gitea:$gitea_password" \
  -X DELETE \
  -H 'Accept: application/json' \
  "$gitea_url/api/v1/repos/gitea/example-argocd" \
  | jq
```

Destroy the stateful applications and their data:

**TODO:** Somehow, do this automatically from `terraform destroy`.

```bash
kubernetes_cluster_name="$(terraform output -raw kubernetes_cluster_name)"

# uninstall gitea.
helm uninstall --namespace gitea gitea --timeout 10m

# delete the gitea pvc and pv.
# NB the pvc is not automatically deleted because it also has a finalizer.
kubectl --namespace gitea get pvc,pv
kubectl --namespace gitea get pvc/gitea
kubectl --namespace gitea delete pvc/gitea

# wait until the pvc and pv are deleted.
kubectl --namespace gitea get pvc,pv

# list all volumes that might still be associated with this kubernetes cluster.
# NB if this list is not empty, you should add another section to this file to
#    explicitly delete it, instead of using aws ec2 delete-volume.
aws ec2 describe-volumes \
  --filters "Name=tag:kubernetes.io/cluster/$kubernetes_cluster_name,Values=*" \
  --query "Volumes[*].{VolumeId:VolumeId,Name:Tags[?Key=='Name']|[0].Value,InstanceId:Attachments[0].InstanceId}" \
  --output json \
  | jq

# if required, delete a volume by id. e.g.:
aws ec2 delete-volume --volume-id vol-1234567890abcdef0
```

List the AWS Application Load Balancers (ALB):

```bash
kubernetes_cluster_name="$(terraform output -raw kubernetes_cluster_name)"
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?Type==`application`].LoadBalancerArn' \
  --output json \
  | jq -r '.[]' \
  | while read arn; do
  tags="$(aws elbv2 describe-tags \
    --resource-arns "$arn" \
    --query 'TagDescriptions[0].Tags' \
    --output json \
    | jq -c)"
  cluster_tag="$(jq -r \
    --arg kubernetes_cluster_name "$kubernetes_cluster_name" \
    '.[] | select(.Key=="elbv2.k8s.aws/cluster" and .Value==$kubernetes_cluster_name) | .Value' \
    <<<"$tags")"
  if [ -n "$cluster_tag" ]; then
    aws elbv2 describe-load-balancers \
      --load-balancer-arns "$arn" \
      --query 'LoadBalancers[0].{LoadBalancerName:LoadBalancerName, DNSName:DNSName, Scheme:Scheme}' \
      --output text
  fi
done
```

Destroy the example:

```bash
make terraform-destroy
```

List this repository dependencies (and which have newer versions):

```bash
GITHUB_COM_TOKEN='YOUR_GITHUB_PERSONAL_TOKEN' ./renovate.sh
```

# Notes

* OpenID Connect Provider for EKS (aka [Enable IAM Roles for Service Accounts (IRSA)](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/setting-up-enable-IAM.html)) is enabled.
  * a [aws_iam_openid_connect_provider resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) is created.

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
