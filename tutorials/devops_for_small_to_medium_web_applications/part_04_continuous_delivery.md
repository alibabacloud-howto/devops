---
layout: default
---
# DevOps for small / medium web apps - Part 4 - Continuous Delivery

## Summary
0. [Introduction](#introduction)
1. High-availability architecture
2. GitLab flow
3. Infrastructure-as-code with Terraform
4. Pipeline improvements
   
## Introduction
In this part we will finally deploy our application in the cloud! We will create 3 environments:
* dev.my-sample-domain.xyz - The "development" environment with the latest features.
* pre-prod.my-sample-domain.xyz - The "pre-production" environment for testing.
* www.my-sample-domain.xyz - The "production" environment for all users.

The two first sections are quite theoretical as they deal with infrastructure decisions to run the application in
the cloud and how we should organize our deployment process.

The section after that introduces [Terraform](https://www.terraform.io/): as you can see in the previous parts of this
tutorial, creating our environment for GitLab and SonarQube with
the [web console](https://home-intl.console.aliyun.com/) is quite slow. Since we will have to create 3 nearly
identical environments, we will use Terraform to speed-up the process.

The final step is to improve our GitLab pipeline in order to make everything automatic.

