# Trend App — Production-Ready Application Deployment

## 1. Project overview

This project packages the supplied React-based Trend application into a Docker image and deploys it to Amazon EKS. Terraform is used to define the AWS infrastructure, while Jenkins automates the build, image publishing and Kubernetes deployment process.

The application is served by Nginx on **port 3000**.

**Source application:** https://github.com/Vennilavanguvi/Trend.git  
**GitHub project repository:** Add your project repository URL here  
**Docker Hub image:** `kannansudalai/trend-app`

## 2. Architecture and workflow

1. A developer pushes a code change to GitHub.
2. The GitHub webhook triggers the Jenkins Pipeline.
3. Jenkins checks out the repository.
4. Jenkins builds the Docker image and tags it with the Jenkins build number and `latest`.
5. Jenkins authenticates to Docker Hub using a Jenkins credential and pushes both tags.
6. Jenkins uses the EC2 instance's IAM role to obtain EKS cluster credentials.
7. Jenkins applies the Kubernetes manifests, updates the Deployment to the build-specific image tag and waits for the rollout.
8. The Kubernetes `LoadBalancer` Service provides an external endpoint for the application.

```text
Developer
   |
   | git push
   v
GitHub repository ---- GitHub webhook ----> Jenkins
                                             |
                                             | docker build
                                             v
                                         Docker image
                                             |
                                             | docker push
                                             v
                                          Docker Hub
                                             |
                                             | kubectl apply / set image
                                             v
                                         Amazon EKS
                                             |
                                             v
                                  Kubernetes LoadBalancer
                                             |
                                             v
                                    Trend App :3000
```

## 3. Repository structure

```text
trend-app/
├── dist/                   # Production React build served by Nginx
│   ├── assets/
│   └── index.html
├── k8s/
│   ├── deployment.yaml     # Kubernetes Deployment
│   └── service.yaml        # Kubernetes LoadBalancer Service
├── terraform/              # AWS infrastructure as code
├── .dockerignore
├── .gitignore
├── Dockerfile
├── Jenkinsfile
└── nginx.conf
```

## 4. Prerequisites

Install and configure the following tools on the machine used for the relevant steps:

- Git
- Docker
- AWS CLI, configured with an AWS identity
- Terraform
- `kubectl`
- Jenkins with Docker, Git, Pipeline and Kubernetes-related tooling/plugins as required
- Access to the GitHub repository and Docker Hub repository

The Jenkins host must have Docker, AWS CLI and `kubectl` installed and available in its `PATH`. It must also be able to reach Docker Hub, GitHub and the EKS API endpoint.

## 5. Application container

### Nginx configuration

`nginx.conf` configures Nginx to listen on port 3000, serve files from `/usr/share/nginx/html`, and route unknown paths to `index.html` for client-side React routing.

```nginx
server {
    listen 3000;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### Dockerfile

The Dockerfile uses the official lightweight Nginx Alpine image, copies the Nginx configuration and the pre-built React `dist/` directory into the image, exposes port 3000 and runs Nginx in the foreground.

```dockerfile
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY dist/ /usr/share/nginx/html/

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]
```

**Build and test locally:**

```bash
docker build -t trend-app:local .
docker run -d --name trend-app-local-test -p 3000:3000 trend-app:local
```

Open `http://localhost:3000` to verify the application.

To inspect or stop the local test container:

```bash
docker ps
docker logs trend-app-local-test
docker stop trend-app-local-test
docker rm trend-app-local-test
```

The supplied project structure contains a pre-built `dist/` directory. If the React source/build process is later added to this repository, consider a multi-stage Docker build that installs dependencies and creates `dist/` inside the build stage. The current Dockerfile expects `dist/` to exist before `docker build`.

## 6. Docker Hub

Create the Docker Hub repository:

```text
kannansudalai/trend-app
```

Create a Docker Hub access token and store it in Jenkins Credentials as a username/password credential with the ID:

```text
dockerhub
```

Do not put the Docker Hub password or access token in the Jenkinsfile, source code or Git repository.

The Jenkins pipeline builds and pushes two tags:

- `kannansudalai/trend-app:<Jenkins build number>`
- `kannansudalai/trend-app:latest`

The build-number tag provides traceability for each pipeline run. The `latest` tag is a convenience tag.

## 7. AWS infrastructure with Terraform

The `terraform/` directory defines the AWS infrastructure used by this deployment. Based on the supplied Terraform configuration, it includes:

- VPC and public/private subnets across Availability Zones
- Network routing resources defined by the VPC module
- IAM role, policies and instance profile for Jenkins
- Jenkins EC2 instance and its security group
- EKS cluster and managed worker node group, if the `eks.tf` configuration is included in the directory

### Terraform workflow

Run these commands from the Terraform configuration directory:

```bash
cd terraform
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Review the plan carefully before applying it. Creating EKS, EC2, NAT gateways, load balancers and related resources can incur AWS charges.

Useful commands:

```bash
terraform output
terraform output -raw jenkins_role_arn
terraform output -raw jenkins_public_ip
```

Keep `terraform.tfvars`, state files and saved plan files out of Git. Keep `.terraform.lock.hcl` under version control so provider selections are reproducible.

### Important configuration check

In the supplied `vpc.tf`, `enable_nat_gateway = false` while the comments describe private-subnet outbound access through NAT. With NAT disabled, private EKS nodes may not have outbound internet access to pull images from Docker Hub unless another egress path or the required private endpoints are configured. Verify the intended network design before provisioning.

Also verify that the `eks.tf` file is present and that its module/provider version constraints are compatible with the versions declared in `versions.tf`.

## 8. Jenkins-to-EKS access

The Jenkins EC2 instance is intended to use an attached IAM role rather than long-lived AWS access keys.

The Jenkins host needs:

- AWS CLI
- `kubectl`
- EKS authentication support through the AWS CLI
- IAM permission to describe the EKS cluster
- EKS cluster access authorization for the Jenkins IAM role

The IAM role's AWS permissions and its authorization inside the Kubernetes cluster are separate requirements. Confirm that the role is granted the appropriate EKS access policy/access entry for the cluster.

Test the connection from the Jenkins host:

```bash
aws sts get-caller-identity
aws eks update-kubeconfig --name trend-cluster --region ap-south-1
kubectl get nodes
```

The `kubectl` client must be installed on the Jenkins EC2 instance. If the shell reports `kubectl: command not found`, install it and ensure its installation directory is in `PATH`.

## 9. Kubernetes manifests

### Deployment

`k8s/deployment.yaml` defines a Deployment named `trend-app` with two replicas. The Pods use the `kannansudalai/trend-app:latest` image initially, expose container port 3000, define an HTTP readiness probe and specify CPU/memory requests and limits.

The Jenkins pipeline subsequently changes the Deployment image to the unique build-number tag.

### Service

`k8s/service.yaml` defines a Service named `trend-service` with type `LoadBalancer`. It selects Pods labelled `app: trend-app` and forwards traffic from service port 3000 to target port 3000.

Apply and inspect the manifests:

```bash
kubectl apply -f k8s/
kubectl get deployments
kubectl get pods -o wide
kubectl get services
kubectl rollout status deployment/trend-app
```

Retrieve the external address after the cloud load balancer has been provisioned:

```bash
kubectl get service trend-service
```

The external address may take a few minutes to appear. Record the resulting load balancer DNS name and the load balancer ARN for the assignment submission. Do not assume the resource is an Application Load Balancer: the actual load balancer type depends on the EKS load-balancing implementation and configuration.

## 10. Jenkins CI/CD pipeline

The root-level `Jenkinsfile` defines these stages:

| Stage | Purpose |
|---|---|
| Checkout | Checks out the Git revision that triggered the pipeline. |
| Build Image | Builds the Docker image with the build-number tag and `latest`. |
| Push Image | Uses the Jenkins `dockerhub` credential to log in and push both tags. |
| Deploy to EKS | Updates kubeconfig, applies the Kubernetes YAML, updates the Deployment image and waits for rollout completion. |

Configure a Jenkins Pipeline job to use the `Jenkinsfile` from the GitHub repository.

The Jenkins host must be able to run Docker commands. The pipeline also assumes the Kubernetes Deployment is named `trend-app` and the container inside it is named `trend-app`, matching the `kubectl set image` command in the Jenkinsfile.

### GitHub webhook

Configure a webhook in the GitHub repository pointing to:

```text
http://<JENKINS_PUBLIC_IP>:8080/github-webhook/
```

Select the push event and enable the webhook. Replace the placeholder with the actual Jenkins public IP or a stable DNS name. Ensure the Jenkins endpoint is reachable from GitHub; for a production setup, use HTTPS and restrict access appropriately.

## 11. Verification checklist

After a pipeline run, verify:

```bash
# Jenkins host: AWS identity and EKS connectivity
aws sts get-caller-identity
kubectl get nodes

# Kubernetes deployment health
kubectl get deployment trend-app
kubectl get pods -l app=trend-app
kubectl rollout status deployment/trend-app

# Service endpoint
kubectl get service trend-service

# Confirm the deployed image
kubectl get deployment trend-app -o jsonpath='{.spec.template.spec.containers[?(@.name=="trend-app")].image}'
```

Also verify that:

- The Jenkins build completed successfully.
- The expected build-number image tag exists in Docker Hub.
- The Deployment is using the image tag produced by that build.
- The Pods are Ready.
- The application loads through the external Service endpoint on port 3000.
- A new GitHub push triggers another Jenkins build.

## 12. Monitoring

The Terraform outputs shown in the project configuration include Jenkins, Prometheus and Grafana URLs. If Prometheus and Grafana are installed and configured on the Jenkins/monitoring EC2 instance, use them to inspect the monitoring setup and capture relevant dashboard screenshots.

Document the actual exporters, scrape targets, dashboards and alerts that are configured. Do not describe monitoring as complete unless it has been installed and verified.

## 13. Evidence and submission

Include the following evidence in the repository or in the submission document:

- Project directory structure
- Successful local Docker build and browser test
- Docker Hub repository and pushed image tags
- Terraform plan/apply output and created AWS resources
- EKS cluster and worker node status
- Jenkins pipeline configuration and successful console output
- GitHub webhook delivery and automatic pipeline trigger
- Kubernetes Deployment, Pods and Service output
- Application running through the external load balancer
- Load balancer ARN requested by the assignment
- Prometheus/Grafana dashboards, if configured

## 14. Security and cost considerations

- Never commit AWS credentials, Docker Hub tokens, private keys, `.tfstate`, saved Terraform plans or `terraform.tfvars`.
- Restrict SSH, Jenkins, Grafana and Prometheus access to trusted networks wherever possible.
- The supplied Jenkins UI CIDR default of `0.0.0.0/0` exposes port 8080 broadly. Prefer HTTPS and a restricted access design; account for GitHub webhook connectivity.
- Review IAM permissions and EKS access before granting cluster-admin access.
- Review NAT, EC2, EKS, EBS and load balancer costs.
- Destroy temporary resources when the assignment is complete, after saving the required evidence.

## 15. Project status

Update this section before submission:

- [ ] GitHub repository URL added
- [ ] Docker Hub image URL added
- [ ] Terraform infrastructure successfully provisioned
- [ ] Jenkins pipeline successful
- [ ] GitHub webhook trigger verified
- [ ] EKS rollout successful
- [ ] Application URL added
- [ ] Load balancer ARN added
- [ ] Monitoring evidence added, if implemented
- [ ] Screenshots/evidence attached
