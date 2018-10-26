---
layout: default
---
# Getting started with DevOps with Kubernetes

## Summary
0. [Introduction](#introduction)
1. [Prerequisite](#prerequisite)
2. [Gitlab environment](#gitlab-environment)
3. [Kubernetes environment](#kubernetes-environment)
4. [Container registry](#container-registry)
5. [CI/CI Pipeline](#ci/ci-pipeline)

## Introduction
The goal of this tutorial is to explain how to create a [CI](https://en.wikipedia.org/wiki/Continuous_integration) /
[CD](https://en.wikipedia.org/wiki/Continuous_delivery) pipeline in order to deploy an application
in [Kubernetes](https://kubernetes.io) running on top of [Alibaba Cloud](https://www.alibabacloud.com/).

The procedure can be summarized in two mains steps:
* Installing the tooling environment (Gitlab and Kubernetes).
* Creating a small Java web application and configuring a CI/CD pipeline around it.

## Prerequisite
The very first step is to [create an Alibaba Cloud account](https://www.alibabacloud.com/help/doc-detail/50482.htm) and
[obtain an access key id and secret](https://www.alibabacloud.com/help/faq-detail/63482.htm).

Cloud resources are created with [Terraform](https://www.terraform.io/) scripts. If you don't know this tool, please
[follow this tutorial](https://www.terraform.io/intro/getting-started/install.html) and familiarize yourself with the
[alicloud provider](https://www.terraform.io/docs/providers/alicloud/index.html).

Please also make sure you are familiarized with Kubernetes. If you need, you can follow
this [awesome tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/) to learn the basics. You will also need
to [setup the command line tool 'kubectl'](https://kubernetes.io/docs/tasks/tools/install-kubectl/).

You should also have [Git](https://git-scm.com/) installed on your computer.

## Gitlab environment
This tutorial uses [Gitlab](https://about.gitlab.com/) to manage Git repositories and to run CI/CD pipelines. The
community edition is free, simple to use and have all the features that we need for this demo.

Open a terminal and enter the following commands with your own access key and
[region](https://www.alibabacloud.com/help/doc-detail/40654.htm) information:
````bash
export ALICLOUD_ACCESS_KEY="your-accesskey-id"
export ALICLOUD_SECRET_KEY="your-accesskey-secret"
export ALICLOUD_REGION="your-region-id"

cd environment/gitlab
terraform init
terraform apply -var 'gitlab_instance_password=YourSecretR00tPassword'
````

Note: this script is a bit too simple to be used in production, for example a SSL certificate should be configured
to allow HTTPS. Here is a 
[more complete tutorial](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-gitlab-on-ubuntu-16-04)
about Gitlab installation.

The output of the script should contain the IP addresses of the newly installed Gitlab instance and
a [Gitlab runner](https://docs.gitlab.com/ce/ci/runners/):
```
Outputs:

gitlab_runner_public_ip = w.x.y.z
gitlab_public_ip = a.b.c.d
```
Please open the page "http://a.b.c.d" (from `gitlab_public_ip`) in your web browser and:
* Set a new password;
* Sign in as "root" (with your new password).

You should be able to see a welcome screen. You can now generate and upload a SSH key:
* Click on your user's avatar on the top-right of the page and select "Settings";
* On the left menu, select the item "SSH Keys";
* If necessary, generate your SSH key as instructed;
* Copy your public key in the textarea (it should be in the file "~/.ssh/id_rsa.pub");
* Click on "Add key".

The next step is to register the Gitlab runner (the ECS instance that runs CI/CD scripts):
* From the top menu, select "Admin area" (the wrench icon);
* From the left menu, select "Overview > Runners";
* The new page must provide an URL and a token under the section "Setup a shared Runner manually", keep this page opened,
  open a terminal and run the following commands:
  ```bash
  ssh root@w.x.y.z # The IP address is from `gitlab_runner_public_ip`. The password is the one you set with `gitlab_instance_password`.
  gitlab-runner register
  ```
  Enter the URL and the token from the web browser tab, set "docker-runner" as the description, choose "docker" as executor
  and set "alpine:latest" as the default Docker image.
* Refresh the web browser tab and check the runner is displayed.

Go back to the home page by clicking on the Gitlab icon on the top-left side of the screen and keep this web browser
tab opened, we will return to it later.

## Kubernetes environment
To keep it simple, this tutorial creates a single-AZ cluster. However, a multi-AZ one is preferred for production. Please
read the [official documentation](https://www.alibabacloud.com/help/doc-detail/86488.htm) for more information.

Open a terminal and enter the following commands with your own access key and region information:
````bash
export ALICLOUD_ACCESS_KEY="your-accesskey-id"
export ALICLOUD_SECRET_KEY="your-accesskey-secret"
export ALICLOUD_REGION="your-region-id"

cd environment/kubernetes
terraform init
terraform apply -var 'k8s_password=YourSecretR00tPassword'
````
Note 0: it takes about 20min to create a Kubernetes cluster.

Note 1: there is known bug with the `alicloud_cs_kubernetes` resource: if you get the error "There is no any nodes
in kubernetes cluster", please re-execute the `terraform apply` command.

Note 2: there is another known bug: if you get the error "output.k8s_master_public_ip: Resource
'alicloud_cs_kubernetes.cluster' does not have attribute 'connections.master_public_ip' for variable
'alicloud_cs_kubernetes.cluster.connections.master_public_ip'", comment the code in "environment/kubernetes/output.tf"
with `/* */`, execute the `terraform apply` command, revert your changes in "environment/kubernetes/output.tf" and
re-execute the `terraform apply` command.

The output of the script should contain the master node public IP address:
```
Outputs:

k8s_master_public_ip = e.f.g.h
```
Execute the following commands in order to configure "kubectl" (the password is the one you set with the
variable `k8s_password`):
````bash
mkdir $HOME/.kube
scp root@e.f.g.h:/etc/kubernetes/kube.conf $HOME/.kube/config # The IP address is the one from `k8s_master_public_ip`

# Check that it works
kubectl cluster-info
````
If the configuration went well, the result of the last command should be something like:
```
Kubernetes master is running at https://161.117.97.242:6443
Heapster is running at https://161.117.97.242:6443/api/v1/namespaces/kube-system/services/heapster/proxy
KubeDNS is running at https://161.117.97.242:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
monitoring-influxdb is running at https://161.117.97.242:6443/api/v1/namespaces/kube-system/services/monitoring-influxdb/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

## Container registry
Unfortunately it is not yet possible to [create a container registry](https://www.alibabacloud.com/product/container-registry)
on Alibaba Cloud via Terraform. Instead, this step must be done manually through the web console:
* Login to the [web console](https://home-intl.console.aliyun.com);
* In the left menu, navigate to "Products > Container Registry";
* Select your region on top of the page;
* Click on the left menu item "Namespace";
* Click on "Create Namespace", set a name such as "cicd-k8s-tutorial" and click on "Confirm";
* Click on the left menu item "Repositories";
* If you don't remember it, you can click on "Reset Docker Login Password".

Keep this page opened in the web browser, we will need to create a repository in the next step.

## CI/CD Pipeline
This tutorial uses a very simple [Spring Boot](https://spring.io/guides/gs/spring-boot/) app as an example. You can find
the source code in the folder `app/simple-rest-service`.

### Docker image repository
The first step is to create a repository where Docker images will be saved. Open you web browser tab from
the [Container registry section](#container-registry) and execute the following instructions:
* Click on "Create Repository", select your namespace, set the repository name to "simple-rest-service",
  set a summary, set the type as "Public", click on "Next", select "Local Repository" as Code Source
  and click on "Create Repository";
* You should now see a list of repositories, click on the "manage" link for your new repository;
* On the new page, copy the "internet" repository address and keep it on the side for the moment.

### Gitlab project
Open the web browser tab you created [in the Gitlab environment section](#gitlab-environment) and create a new project:
* From the home page, click on "Create a project";
* Set the name "simple-rest-service" and click on "Create project";
* Once the project is created, in the left menu select "Settings > CI/CD";
* Expand the "Variables" panel, and create the following variables:
  * DOCKER_REGISTRY_IMAGE_URL = "internet" repository address you got from the [Docker image repository section](#docker-image-repository)
  * DOCKER_REGISTRY_USERNAME = Alibaba Cloud account username
  * DOCKER_REGISTRY_PASSWORD = Docker Login Password you might have reset in the [Container registry section](#container-registry)
  * K8S_MASTER_PUBLIC_IP = The Kubernetes cluster public IP (from `k8s_master_public_ip`)
  * K8S_PASSWORD = The Kubernetes password (from `k8s_password`)

The project repository is now ready to host files:
* Open a terminal on your local machine and type:
  ```bash
  mkdir -p $HOME/projects
  cd $HOME/projects
  git clone git@a.b.c.d:root/simple-rest-service.git # The IP address comes from `gitlab_public_ip`
  cd simple-rest-service
  ```
* Copy the following files from "app/simple-rest-service" into the new folder "$HOME/projects/simple-rest-service":
  * src            - Sample application source code
  * pom.xml        - [Maven](https://maven.apache.org/) project descriptor (declares dependencies and packaging information for the application)
  * deployment.yml - Kubernetes deployment descriptor (describes the deployment and a load balancer service)
  * .gitlab-ci.yml - CI/CD descriptor (used by Gitlab to create a pipeline)
* In your terminal, type:
  ```bash
  git add .gitlab-ci.yml deployment.yml pom.xml src/
  git commit -m "Initial commit"
  git push origin master
  ```
  Note: if you have an error when you try to push your code, it may be due to the fact that the master branch is
  automatically protected. In this case, go to the Gitlab web browser tab, navigate into "Settings > Repository >
  Protected Branches", type "master" in the Branch attribute, and select "create wildcard master".

Gitlab automatically recognizes the file ".gitlab-ci.yml" and create a pipeline with 3 steps:
0. Compile and execute unit tests;
1. Create the Docker image with [JIB](https://github.com/GoogleContainerTools/jib) and upload it to
   the [Docker image repository](#docker-image-repository);
2. Deploy the application in Kubernetes.

You can see the pipeline in Gitlab by selecting the item "CI / CD > Pipelines" from the left menu.

After you pipeline has been executed completely, you can check you Kubernetes cluster with the following commands:
* Check the deployments:
  ```bash
  kubectl get deployments
  ```
  The result should be something like:
  ```
  NAME                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
  simple-rest-service   2         2         2            2           21m
  ```
* Check the pods:
  ```bash
  kubectl get pods
  ```
  The result should be something like:
  ```
  NAME                                   READY   STATUS    RESTARTS   AGE
  simple-rest-service-5b9c496d5d-5n6vl   1/1     Running   0          18m
  simple-rest-service-5b9c496d5d-h758n   1/1     Running   0          18m
  ```
* Check the services:
  ```bash
  kubectl get services
  ```
  The result should be something like:
  ```
  NAME                      TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)        AGE
  simple-rest-service-svc   LoadBalancer   10.1.214.231   161.117.73.86   80:30571/TCP   23m
  ```
* Check the logs of one pod:
  ```bash
  kubectl logs simple-rest-service-5b9c496d5d-5n6vl
  ```
  The result should start with:
  ```
      .   ____          _            __ _ _
     /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
    ( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
     \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
      '  |____| .__|_| |_|_| |_\__, | / / / /
     =========|_|==============|___/=/_/_/_/
     :: Spring Boot ::        (v2.0.5.RELEASE)
  ```

Test the application by yourself:
* Open a new tab in your web browser and visit "http://161.117.73.86" (the service EXTERNAL-IP): you should see the
  "Hello world!" message;
* Add "?name=Seven" to the URL (so it should be something like "http://161.117.73.86?name=Seven"): you should see the
  "Hello Seven!" message.
