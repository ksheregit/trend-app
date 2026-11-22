pipeline {
    agent any    // run on this Jenkins server itself (it has docker, kubectl and aws installed)

    environment {
        IMAGE   = "<dockerhub-user>/trend-app"   // your Docker Hub repo
        TAG     = "${env.BUILD_NUMBER}"          // 1, 2, 3 ... every build gets a unique tag, so you can tell versions apart
        CLUSTER = "trend-cluster"                // must match eks_cluster_name in Terraform
        REGION  = "ap-south-1"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm    // pull the repo that triggered this build
            }
        }

        stage('Build Image') {
            steps {
                // Build once, tag twice: a numbered tag for traceability and "latest" for convenience
                sh 'docker build -t $IMAGE:$TAG -t $IMAGE:latest .'
            }
        }

        stage('Push Image') {
            steps {
                // Reads the Docker Hub username and token from Jenkins credentials.
                // The ID below must match the credential ID you created in Jenkins.
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_PASS')]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        docker push $IMAGE:$TAG
                        docker push $IMAGE:latest
                    '''
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh '''
                    # Point kubectl at the cluster. Uses the server's IAM role, so no keys are needed.
                    aws eks update-kubeconfig --name $CLUSTER --region $REGION

                    # Create or update the Deployment and Service from the YAML files
                    kubectl apply -f k8s/

                    # Roll the Deployment to the image tag this build just pushed
                    kubectl set image deployment/trend-app trend-app=$IMAGE:$TAG

                    # Wait until the new pods are healthy. This fails the build if they never are.
                    kubectl rollout status deployment/trend-app --timeout=180s
                '''
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'    // don't leave Docker Hub credentials on the server
        }
    }
}