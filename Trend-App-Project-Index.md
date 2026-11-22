# Project Index — Trend App Deployment

**Project:** Trendify / Trend App — Production-ready React application deployment  
**Repository:** https://github.com/Vennilavanguvi/Trend.git  
**Application port:** 3000

## Implementation steps

| Step | Activity | What is covered |
|---:|---|---|
| 1 | Prepare the workstation and tools | Verify Git, Docker, AWS CLI, kubectl, Terraform and access to AWS, GitHub and Docker Hub. |
| 2 | Obtain the React application | Clone the supplied Trend repository and review the application files and production build (`dist/`). |
| 3 | Prepare the deployment project | Create the project structure and organize the `terraform/` and `k8s/` directories. |
| 4 | Configure Nginx and container build files | Create `nginx.conf`, `Dockerfile`, `.gitignore` and `.dockerignore`; configure Nginx to serve the React build on port 3000. |
| 5 | Build and test the Docker image locally | Build the image, run a container with port mapping `3000:3000`, and verify the application in a browser. |
| 6 | Set up Git version control | Initialize the project repository, create commits, configure the GitHub remote and push the source code. |
| 7 | Create the Docker Hub repository | Create the image repository and a Docker Hub access token for automated image publishing. |
| 8 | Build and publish the application image | Tag the image, authenticate securely and push versioned and `latest` tags to Docker Hub. |
| 9 | Provision AWS infrastructure with Terraform | Initialize, format, validate and plan the Terraform configuration; provision the VPC, subnets, IAM resources, Jenkins EC2 instance and EKS resources defined in the configuration. |
| 10 | Configure Jenkins access to EKS | Attach the required IAM identity to Jenkins and configure EKS access so Jenkins can authenticate to the cluster without hard-coded AWS keys. |
| 11 | Create Kubernetes manifests | Define the application Deployment, replicas, container image, port, readiness probe and resource requests/limits in `k8s/deployment.yaml`; expose it using `k8s/service.yaml`. |
| 12 | Validate deployment to EKS | Configure kubeconfig, apply the Kubernetes manifests and verify pods, deployment rollout, service and application endpoint using `kubectl`. |
| 13 | Configure Jenkins and pipeline credentials | Install/configure the required Jenkins plugins, create Docker Hub credentials with the ID expected by the Jenkinsfile (`dockerhub`), and configure the Pipeline job to use the repository's `Jenkinsfile`. |
| 14 | Integrate GitHub webhook with Jenkins | Configure the GitHub webhook to trigger the Jenkins pipeline when changes are pushed to the repository. |
| 15 | Run and verify the CI/CD workflow | Push a code change, confirm Jenkins checks out the code, builds and pushes a uniquely tagged image, deploys it to EKS, and waits for a successful rollout. Capture the application URL, pipeline output and Kubernetes evidence. |

## Project files

- `Dockerfile` — builds the Nginx-based application container from the production `dist/` files.
- `nginx.conf` — configures Nginx to listen on port 3000 and fall back to `index.html` for React routes.
- `Jenkinsfile` — defines checkout, image build, Docker Hub push and EKS deployment stages.
- `k8s/deployment.yaml` — defines the application Pods through a Kubernetes Deployment.
- `k8s/service.yaml` — exposes the application through a Kubernetes `LoadBalancer` Service.
- `terraform/` — contains the infrastructure configuration for AWS resources.
- `.gitignore` and `.dockerignore` — exclude files from Git and Docker build contexts respectively.

> **Documentation note:** This index follows the current Jenkins + Docker Hub workflow described in the project files. It does not include the older CodeBuild/CodePipeline + ECR workflow shown in the earlier project report.
