---
layout: default
---
# DevOps for small / medium web apps - Part 4 - Continuous Delivery

## Summary
0. [Introduction](#introduction)
1. [Highly available architecture](#highly-available-architecture)
2. [GitLab flow](#gitlab-flow)
3. [Infrastructure-as-code with Terraform](#infrastructure-as-code-with-terraform)
4. [VM image generation with Packer](#vm-image-generation-with-packer)
5. [Application infrastructure](#application-infrastructure)
6. Infrastructure pipeline stage
7. Database update pipeline stage
8. Application installation pipeline stage
9. Pre-production and production environments

## Introduction
In this part we will finally deploy our application in the cloud!

We will create 3 environments:
* dev.my-sample-domain.xyz - The "development" environment with the latest features.
* pre-prod.my-sample-domain.xyz - The "pre-production" environment for testing.
* www.my-sample-domain.xyz - The "production" environment for all users.

The two first sections are quite theoretical as they deal with cloud infrastructure design and development & deployment
process.

The section after that introduces [Terraform](https://www.terraform.io/): as you can see in the previous parts of this
tutorial, creating our environment for GitLab and SonarQube with
the [web console](https://home-intl.console.aliyun.com/) is quite slow. Since we will have to create 3 nearly
identical environments, we will use Terraform to speed-up the process.

The final step is to improve our GitLab pipeline in order to make everything automatic.

## Highly available architecture
The goal is to be able to serve our web application to users even in case of hardware or network failure.

The following diagram shows a simplified view of our architecture:

![HA architecture](images/diagrams/ha-architecture.png)

As you can see we are duplicating each cloud resource into two availability zones (zone A and zone B): since these zones
are independents, a problem in one zone (e.g. machine/network failure) does not affect the other one.

Our application will run on two ECS instances. The traffic from internet is redirected thanks to a server load balancer
installed in front of them.

For the data storage layer we use [ApsaraDB RDS for MySQL](https://www.alibabacloud.com/product/apsaradb-for-rds-mysql),
a managed database service that handles server installation, maintenance, automatic backup, ...etc.

Note: with this diagram you can understand why a stateless application is important: the only place where data can be
shared is the database, so we don't need to establish a direct link between the applications. Moreover, if two users
are modifying the same data (e.g. by deleting the same item), the database will handle transactions for us, keep
the data consistent and reject one user modification.

## GitLab flow
Until now our development workflow was very simple: modify some source code, commit it into the master branch and push
it to GitLab. This is fine at the beginning (single developer, no deployed version), but we need to enrich this process
in order to properly manage our releases. For that [GitLab Flow](https://docs.gitlab.com/ee/workflow/gitlab_flow.html)
is a good solution: simple but rich enough for our needs.

The following diagram illustrates how we will use GitLab Flow in this tutorial:

![GitLab Flow](images/diagrams/gitlab_flow.png)

The long horizontal arrows corresponds to long-lived branches (master, pre-production and production), a circle
represents a commit, and the timeline goes from the left to the right (a commit on the left is older than a commit on
the right).

The two short horizontal branches on the top correspond to short-lived branches: they are used to implement new features
or bug fixes. In this example, two developers work on two features in parallel ("feature_a" and "feature_b"). When
the "feature_a" is finished, the developer emits
a [merge request](https://docs.gitlab.com/ee/user/project/merge_requests/) from his branch to the master. This is
usually a good time for [code review](https://en.wikipedia.org/wiki/Code_review): another developer can check the
modifications and accept / reject the request. If accepted, the feature branch is merged into the master and closed.
In this example, the developer on the "feature_b" merges the new commit from the master branch corresponding to the
"feature_a" to his own branch. He later can emit a merge request to merge his branch to the master.

On the right, the blocks correspond to environments (one environment = an EIP, a server load balancer, two ECS instances
and a RDS instance). Everytime a commit is done in the master branch, the CI / CD pipeline compiles, tests, analyzes
the code, updates the database schema and installs the new application version on the ECS instances. The process is the
same with the pre-production and production branches: it allows us to manage releases by emitting a merge request
from the master branch to the pre-production one and from the pre-production one to the production one.

## Infrastructure-as-code with Terraform
The problem with creating cloud resources with the web console is that it is quite tedious and error prone, especially
when this process must be repeated for 3 environments. An elegant solution is to
use [Terraform](https://www.terraform.io/): we write a script that describes our architecture (in
the [HCL language](https://www.terraform.io/docs/configuration/syntax.html)) and we ask Terraform to create / update our
cloud environment accordingly.

Let's test Terraform before using it for our project. Please
[install it](https://www.terraform.io/intro/getting-started/install.html) on your computer (download the binary package
and add it to your [PATH variable](https://en.wikipedia.org/wiki/PATH_(variable))), then open a terminal and run:
```bash
# Create a folder for our test
mkdir -p ~/projects/terraform-test

cd ~/projects/terraform-test

# Create a sample script
nano test.tf
```
Copy the following content into your script:
```hcl-terraform
// Use Alibaba Cloud provider (https://github.com/terraform-providers/terraform-provider-alicloud)
provider "alicloud" {}

// Sample VPC
resource "alicloud_vpc" "sample_vpc" {
  name = "sample-vpc"
  cidr_block = "192.168.0.0/16"
}
```
Save and quit with CTRL+X, and execute:
```bash
# Download the latest stable version of the Alibaba Cloud provider
terraform init

# Configure the Alibaba Cloud provider
export ALICLOUD_ACCESS_KEY="your-accesskey-id"
export ALICLOUD_SECRET_KEY="your-accesskey-secret"
export ALICLOUD_REGION="your-region-id"

# Create the resources in the cloud
terraform apply
```
Note: the values to set in `ALICLOUD_ACCESS_KEY` and `ALICLOUD_SECRET_KEY` are your access key ID and secret, you
have already used them when you configured automatic backup for GitLab in the
[part 1 of this tutorial](part_01_gitlab_installation_and_configuration.md)). About `ALICLOUD_REGION`, the available
values can be found [in this page](https://www.alibabacloud.com/help/doc-detail/40654.htm).

The last command should print something like this:
```
An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  + alicloud_vpc.sample_vpc
      id:              <computed>
      cidr_block:      "192.168.0.0/16"
      name:            "sample-vpc"
      route_table_id:  <computed>
      router_id:       <computed>
      router_table_id: <computed>


Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: 
```
Terraform displays its plan of its modifications. As you can see only one resource will be added (the VPC). Enter
the value `yes` and press ENTER. The result should be something like this:
```
alicloud_vpc.sample_vpc: Creating...
  cidr_block:      "" => "192.168.0.0/16"
  name:            "" => "sample-vpc"
  route_table_id:  "" => "<computed>"
  router_id:       "" => "<computed>"
  router_table_id: "" => "<computed>"
alicloud_vpc.sample_vpc: Creation complete after 7s (ID: vpc-t4nhi7y0wpzkfr2auxc0p)

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

Let's check the result:
* Go to the [VPC console](https://vpc.console.aliyun.com/);
* Select your region on top of the page;
* Check the table of VPC, you should be able to see "sample-vpc":

![VPC created with Terraform](images/terraform-sample-vpc.png)

A very interesting feature of Terraform is that it is idempotent. We can check that with the following command:
```bash
# Run Terraform again
terraform apply
```
Terraform interacts with the [Alibaba Cloud APIs](https://api.aliyun.com/) to check what are the existing resources,
then compares them to our script and decides no modification need to be done. You can see it in the console:
```
alicloud_vpc.sample_vpc: Refreshing state... (ID: vpc-t4nhi7y0wpzkfr2auxc0p)

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

Behind the scene Terraform creates two files "terraform.tfstate" and "terraform.tfstate.backup". The first one contains
all the resources information that have been created. These files are important and should usually be shared among
the team (on an OSS bucket for example).

Another interesting feature is that Terraform is able to update an existing architecture. Let's check it by ourselves:
```bash
# Open our sample script
nano test.tf
```
Add the following "vswitch" block in order to obtain the following result:
```hcl-terraform
// Use Alibaba Cloud provider (https://github.com/terraform-providers/terraform-provider-alicloud)
provider "alicloud" {}

// Sample VPC
resource "alicloud_vpc" "sample_vpc" {
  name = "sample-vpc"
  cidr_block = "192.168.0.0/16"
}

// Query Alibaba Cloud about the availability zones in the current region
data "alicloud_zones" "az" {
  network_type = "Vpc"
}

// Sample VSwitch
resource "alicloud_vswitch" "sample_vswitch" {
  name = "sample-vswitch"
  availability_zone = "${data.alicloud_zones.az.zones.0.id}"
  cidr_block = "192.168.1.0/24"
  vpc_id = "${alicloud_vpc.sample_vpc.id}"
}
```
As you can see, we can use expressions like `${variable}` to refer the resources with each others. We can also use
a [data source](https://www.terraform.io/docs/configuration/data-sources.html) to query some information from
Alibaba Cloud.

Save and quit with CTRL+X, and run the following command:
```bash
# Update our cloud resources
terraform apply
```
This time Terraform sees that it doesn't need to re-create the VPC, but it can see it has to create the VSwitch:
```
alicloud_vpc.sample_vpc: Refreshing state... (ID: vpc-t4nhi7y0wpzkfr2auxc0p)
data.alicloud_zones.az: Refreshing state...

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  + alicloud_vswitch.sample_vswitch
      id:                <computed>
      availability_zone: "ap-southeast-1a"
      cidr_block:        "192.168.1.0/24"
      name:              "sample-vswitch"
      vpc_id:            "vpc-t4nhi7y0wpzkfr2auxc0p"


Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: 
```
Enter `yes` and press ENTER. The VSwitch should be created in few seconds:
```
alicloud_vswitch.sample_vswitch: Creating...
  availability_zone: "" => "ap-southeast-1a"
  cidr_block:        "" => "192.168.1.0/24"
  name:              "" => "sample-vswitch"
  vpc_id:            "" => "vpc-t4nhi7y0wpzkfr2auxc0p"
alicloud_vswitch.sample_vswitch: Creation complete after 7s (ID: vsw-t4nvtqld0ktk4kddxq709)

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

Check it worked with the web console:
* Refresh your web browser tab with the [VPC console](https://vpc.console.aliyun.com/);
* If necessary, select your region on top of the page;
* Click on the ID of your VPC "sample-vpc";
* Scroll down and click on the '1' next to "VSwitch";

You should be able to see your sample VSwitch:

![VSwitch created with Terraform](images/terraform-sample-vswitch.png)

Congratulation if you managed to get this far! Let's now release our cloud resources. With your terminal execute
the following command:
```bash
# Release our cloud resources
terraform destroy
```
Terraform print its plan as usual:
```
alicloud_vpc.sample_vpc: Refreshing state... (ID: vpc-t4nhi7y0wpzkfr2auxc0p)
data.alicloud_zones.az: Refreshing state...
alicloud_vswitch.sample_vswitch: Refreshing state... (ID: vsw-t4nvtqld0ktk4kddxq709)

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  - alicloud_vpc.sample_vpc

  - alicloud_vswitch.sample_vswitch


Plan: 0 to add, 0 to change, 2 to destroy.

Do you really want to destroy?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: 
```
Enter `yes` and press ENTER. The resources should be released in few seconds:
```
alicloud_vswitch.sample_vswitch: Destroying... (ID: vsw-t4nvtqld0ktk4kddxq709)
alicloud_vswitch.sample_vswitch: Destruction complete after 1s
alicloud_vpc.sample_vpc: Destroying... (ID: vpc-t4nhi7y0wpzkfr2auxc0p)
alicloud_vpc.sample_vpc: Destruction complete after 3s

Destroy complete! Resources: 2 destroyed.
```

As you can see the fact that Terraform checks existing cloud resources and then compares them to our scripts allows us
to create a new pipeline stage to run "terraform apply": at the first execution cloud resources will be created, at the
next executions Terraform will not modify anything.

We will commit the Terraform scripts with the application source code, like this modifications in the application code
will always be in sync with the infrastructure code.

However this approach has one drawback: like scripts that modifies database schemas, we need to make sure we don't
break things and keep compatibility in case we need to rollback our application to an old version.

## VM image generation with Packer
[Packer](https://www.packer.io) is a tool made by the [same company](https://www.hashicorp.com/) as the one who
develops Terraform. It allows us to create [an image](https://www.alibabacloud.com/help/doc-detail/25460.htm)
containing our already-configured application. The goal is to be able to create an ECS instance with an image where
everything is already configured (no need to login to the machine via SSH and install or execute applications). This
solution is particularly handy for [auto scaling](https://www.alibabacloud.com/product/auto-scaling).

Let's test Packer before using it for our project. Please
[install it](https://www.packer.io/intro/getting-started/install.html) on your computer (download the binary package
and add it to your [PATH variable](https://en.wikipedia.org/wiki/PATH_(variable))), then open a terminal and run:
```bash
# Create a folder for our test
mkdir -p ~/projects/packer-test

cd ~/projects/packer-test

# Create a sample configuration
nano test.json
```
Copy the following content into your script:
```json
{
  "variables": {
    "access_key": "{{env `ALICLOUD_ACCESS_KEY`}}",
    "secret_key": "{{env `ALICLOUD_SECRET_KEY`}}",
    "region_id": "{{env `ALICLOUD_REGION`}}",
    "source_image": "{{env `SOURCE_IMAGE`}}",
    "instance_type": "{{env `INSTANCE_TYPE`}}"
  },
  "builders": [
    {
      "type": "alicloud-ecs",
      "access_key": "{{user `access_key`}}",
      "secret_key": "{{user `secret_key`}}",
      "region": "{{user `region_id`}}",
      "image_name": "sample-image",
      "image_description": "Sample image for testing Packer.",
      "image_version": "1.0",
      "source_image": "{{user `source_image`}}",
      "ssh_username": "root",
      "instance_type": "{{user `instance_type`}}",
      "io_optimized": "true",
      "internet_charge_type": "PayByTraffic",
      "image_force_delete": "true"
    }
  ],
  "provisioners": [
    {
      "type": "shell",
      "inline": [
        "apt-get -y update",
        "apt-get -y upgrade",
        "apt-get -y install nginx",
        "systemctl start nginx",
        "systemctl enable nginx",
        "sleep 10",
        "curl http://localhost"
      ],
      "pause_before": "30s"
    }
  ]
}
```
Save and quit with CTRL+X.

Before we can run this script we need to know the exact source image and instance type available in your region. Open
a new web browser tab and follow these instructions:
* Go to [OpenAPI Explorer](https://api.aliyun.com/#product=Ecs&api=DescribeInstanceTypes);
* If it is not already the case, select the "ECS" product on the left menu, and the "DescribeInstanceTypes"
  service on the left sub-menu;
* Enter your [region ID](https://www.alibabacloud.com/help/doc-detail/40654.htm) in the "RegionId"
  field (e.g. ap-southeast-1);
* Click on the "Submit Request" button at the bottom;
* If needed, this website will ask you to login with your Alibaba Cloud account;
* The "Response Result" panel on the right should contain a tree of instance types; expand each instance type until you
  find one with "MemorySize" equals to 1 or more, then save the value of its "InstanceTypeId" (e.g. ecs.n1.small);
* Select the ["DescribeImages" service](https://api.aliyun.com/#product=Ecs&api=DescribeImages) on the left sub-menu;
* Enter your region ID in the "RegionId" field (e.g. ap-southeast-1);
* Enter "ubuntu\*64\*" in the "ImageName" field;
* Enter "system" in the "ImageOwnerAlias" field;
* Click on the "Submit Request" button at the bottom;
* The "Response Result" panel should contain a tree of available images; expand each image and save the value of the
  most recent "ImageId" (e.g. ubuntu_16_0402_64_20G_alibase_20180409.vhd);

Now that we have the "InstanceTypeId" and "ImageId", go back to your terminal and type:
```bash
# Configure the Alibaba Cloud provider
export ALICLOUD_ACCESS_KEY="your-accesskey-id"
export ALICLOUD_SECRET_KEY="your-accesskey-secret"
export ALICLOUD_REGION="your-region-id"
export SOURCE_IMAGE="your-ImageId"
export INSTANCE_TYPE="your-InstanceTypeId"

# Create the image in the cloud
packer build test.json
```
Packer should output something like this:
```
alicloud-ecs output will be in this color.

==> alicloud-ecs: Force delete flag found, skipping prevalidating image name.
    alicloud-ecs: Found image ID: ubuntu_16_0402_64_20G_alibase_20180409.vhd
==> alicloud-ecs: Creating temporary keypair: packer_5bea5aa2-e524-1af8-80d1-1db78347ed15
==> alicloud-ecs: Creating vpc
==> alicloud-ecs: Creating vswitch...
==> alicloud-ecs: Creating security groups...
==> alicloud-ecs: Creating instance.
==> alicloud-ecs: Allocating eip
==> alicloud-ecs: Allocated eip 47.74.178.35
    alicloud-ecs: Attach keypair packer_5bea5aa2-e524-1af8-80d1-1db78347ed15 to instance: i-t4nhcv8qx069trkfgye6
==> alicloud-ecs: Starting instance: i-t4nhcv8qx069trkfgye6
==> alicloud-ecs: Using ssh communicator to connect: 47.74.178.35
==> alicloud-ecs: Waiting for SSH to become available...
==> alicloud-ecs: Connected to SSH!
==> alicloud-ecs: Pausing 30s before the next provisioner...
==> alicloud-ecs: Provisioning with shell script: /var/folders/v1/jvjz3zmn64q0j34yc9m9n4w00000gn/T/packer-shell047404213
    alicloud-ecs: Get:1 http://mirrors.cloud.aliyuncs.com/ubuntu xenial InRelease [247 kB]
    alicloud-ecs: Get:2 http://mirrors.cloud.aliyuncs.com/ubuntu xenial-updates InRelease [109 kB]
[...]
    alicloud-ecs: 142 upgraded, 0 newly installed, 0 to remove and 4 not upgraded.
[...]
    alicloud-ecs: The following NEW packages will be installed:
    alicloud-ecs:   fontconfig-config fonts-dejavu-core libfontconfig1 libgd3 libvpx3 libxpm4
    alicloud-ecs:   libxslt1.1 nginx nginx-common nginx-core
    alicloud-ecs: 0 upgraded, 10 newly installed, 0 to remove and 4 not upgraded.
[...]
    alicloud-ecs: Executing /lib/systemd/systemd-sysv-install enable nginx
    alicloud-ecs:   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
    alicloud-ecs:                                  Dload  Upload   Total   Spent    Left  Speed
    alicloud-ecs: 100   612  100   612    0     0  81415      0 --:--:-- --:--:-- --:--:-- 87428
    alicloud-ecs: <!DOCTYPE html>
    alicloud-ecs: <html>
    alicloud-ecs: <head>
    alicloud-ecs: <title>Welcome to nginx!</title>
    alicloud-ecs: <style>
    alicloud-ecs:     body {
    alicloud-ecs:         width: 35em;
    alicloud-ecs:         margin: 0 auto;
    alicloud-ecs:         font-family: Tahoma, Verdana, Arial, sans-serif;
    alicloud-ecs:     }
    alicloud-ecs: </style>
    alicloud-ecs: </head>
    alicloud-ecs: <body>
    alicloud-ecs: <h1>Welcome to nginx!</h1>
    alicloud-ecs: <p>If you see this page, the nginx web server is successfully installed and
    alicloud-ecs: working. Further configuration is required.</p>
    alicloud-ecs:
    alicloud-ecs: <p>For online documentation and support please refer to
    alicloud-ecs: <a href="http://nginx.org/">nginx.org</a>.<br/>
    alicloud-ecs: Commercial support is available at
    alicloud-ecs: <a href="http://nginx.com/">nginx.com</a>.</p>
    alicloud-ecs:
    alicloud-ecs: <p><em>Thank you for using nginx.</em></p>
    alicloud-ecs: </body>
    alicloud-ecs: </html>
==> alicloud-ecs: Stopping instance: i-t4nhcv8qx069trkfgye6
==> alicloud-ecs: Waiting instance stopped: i-t4nhcv8qx069trkfgye6
==> alicloud-ecs: Creating image: sample-image
    alicloud-ecs: Detach keypair packer_5bea5aa2-e524-1af8-80d1-1db78347ed15 from instance: i-t4nhcv8qx069trkfgye6
==> alicloud-ecs: Cleaning up 'EIP'
==> alicloud-ecs: Cleaning up 'instance'
==> alicloud-ecs: Cleaning up 'security group'
==> alicloud-ecs: Cleaning up 'vSwitch'
==> alicloud-ecs: Cleaning up 'VPC'
==> alicloud-ecs: Deleting temporary keypair...
Build 'alicloud-ecs' finished.

==> Builds finished. The artifacts of successful builds are:
--> alicloud-ecs: Alicloud images were created:

ap-southeast-1: m-t4n938t1plplyl7akeor
```
The last line contains the ID of the image we have just created (here "m-t4n938t1plplyl7akeor"). Before we go
further, let's study what Packer did with our script:

0. Create an ECS instance and necessary cloud resources (keypair, vpc, vswitch, security group, eip);
1. Connect to the ECS instance via SSH;
2. Wait for 30 seconds (to make sure the VM is completely started);
3. Update the machine (`apt-get -y update` and `apt-get -y upgrade`);
4. Install [Nginx](https://nginx.org/en/) (`apt-get -y install nginx`);
5. Start Nginx and configure
   [SystemD](https://www.freedesktop.org/software/systemd/man/systemctl.html#enable%20UNIT%E2%80%A6) to start it when
   the machine boots (`systemctl start nginx` and `systemctl enable nginx`);
6. Wait for 10 seconds (to make sure Nginx is started);
7. Test Nginx by sending a HTTP request to "http://localhost" (`curl http://localhost`);
8. Stop the ECS instance;
9. Create a [snapshot](https://www.alibabacloud.com/help/doc-detail/25455.htm) of the system disk and convert it to
   an image;
10. Release all cloud resources (eip, ecs, security group, vswitch, vpc, keypair).

You can check the newly created image via the web console:
* Open the [ECS console](https://ecs.console.aliyun.com/);
* Select "Images" in the left menu;
* If necessary, select your region on the top of the page;
* You should be able to see your new image:

![Sample image made with Packer](images/packer-sample-image.png)

* If you want, you can test this image by clicking on the "Create Instance" link on the left;
* When you are done, you can delete this image by selecting its checkbox and by clicking on the "Delete" button at the
  bottom of the page;

## Application infrastructure
In this section we will create Terraform scripts that will create resources for one environment:
* 1 [VPC](https://www.alibabacloud.com/product/vpc)
* 2 [VSwitches](https://www.alibabacloud.com/help/doc-detail/65387.htm) (one per availability zone)
* 1 [Security group](https://www.alibabacloud.com/help/doc-detail/25387.htm)
* 2 [ECS instances](https://www.alibabacloud.com/product/ecs) (one per availability zone)
* 1 [Multi-zone MySQL RDS](https://www.alibabacloud.com/product/apsaradb-for-rds-mysql)
* 1 [SLB instance](https://www.alibabacloud.com/product/server-load-balancer)
* 1 [EIP](https://www.alibabacloud.com/product/eip)

