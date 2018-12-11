---
layout: default
---
# DevOps for small / medium web apps - Part 6 - Maintenance and evolution

## Summary
0. [Introduction](#introduction)
1. [Logs management](#logs-management)
   1. [Log Service configuration](#log-service-configuration)
   2. [Log search](#log-search)
2. Monitoring and alarms
3. Database schema evolution
4. User management
5. Decommissioning

## Introduction
This document is the last "must-read" part of the tutorial in order to build a professional web application with
Alibaba Cloud (the next parts are more optional as they will mainly deal with improvements).

This part covers several important points:
* Log collection and search;
* System monitoring and alarms;
* Database schema evolution
* User management
* Decommissioning

Note: please find the source code containing the changes of this part in the "sample-app/version5" folder.

## Logs management
Working with application logs become more complex when the number of servers increase: for example when there is only
one server, an administrator just needs to connect to this machine and read the "/var/logs" folder and execute
commands such as `journalctl --unit=todo-list`. But when the number of servers increase, the same administrator
must connect to each machine in order to find the information he's looking for. This become even worse when auto-scaling
is enabled, because servers are automatically created and released.

A solution to this problem is to use the [Log Service](https://www.alibabacloud.com/product/log-service): its role
is to collect logs from servers and let administrators / developers to make search into them.

### Log Service configuration
The first step is to create a [Log Project](https://www.alibabacloud.com/help/doc-detail/48873.htm) and a
[Log Store](https://www.alibabacloud.com/help/doc-detail/48874.htm) for our application by modifying our basis
infrastructure script. Open a terminal on your computer and type:
```bash
# Go to the project folder
cd ~/projects/todolist

# Edit the Terraform script of the basis part
nano infrastructure/05_vpc_slb_eip_domain/main.tf
```
Add the following code at the end of the file:
```hcl-terraform
// Log project and store
resource "alicloud_log_project" "app_log_project" {
  name = "sample-app-log-project-${var.env}"
  description = "Sample web application log project (${var.env} environment)."
}
resource "alicloud_log_store" "app_log_store" {
  project = "${alicloud_log_project.app_log_project.name}"
  name = "sample-app-log-store-${var.env}"
}
```
Save the changes by pressing CTRL+X.

The second step is to create a [machine group](https://www.alibabacloud.com/help/doc-detail/28966.htm) for the
ECS instances that host our application. Enter the following commands in your terminal:
```bash
# Edit the 
nano infrastructure/10_webapp/15_ecs/main.tf
```
Add the following code at the end of the file:
```hcl-terraform
// Log machine group
resource "alicloud_log_machine_group" "example" {
  project = "sample-app-log-project-${var.env}"
  name = "sample-app-log-machine-group-${var.env}"
  identify_list = [
    "${alicloud_instance.app_ecs_zone_0.private_ip}",
    "${alicloud_instance.app_ecs_zone_1.private_ip}"
  ]
}
```
Save the changes by pressing CTRL+X.

Note: as you can see, we use the private IP addresses to include ECS machines into the group.

The third step is to create a machine group for the certificate manager instance. Open the corresponding script
with your terminal:
```bash
# Edit the 
nano infrastructure/15_certman/10_ecs_slb_rule/main.tf
```
Add the following code at the end of the file:
```hcl-terraform
// Log machine group
resource "alicloud_log_machine_group" "example" {
  project = "sample-app-log-project-${var.env}"
  name = "sample-app-certman-log-machine-group-${var.env}"
  identify_list = [
    "${alicloud_instance.certman_ecs.private_ip}"
  ]
}
```
Save the changes by pressing CTRL+X.

--- TODO ---
TODO: modify the Packer scripts to setup logtail:
wget http://logtail-release-ap-southeast-1.oss-ap-southeast-1.aliyuncs.com/linux64/logtail.sh -O logtail.sh
chmod 755 logtail.sh
./logtail.sh install auto

Modify the configuration of logtail:
"streamlog_formats":
[
    {"version": "0.1", "fields": []},
]


Modify the conf /etc/rsyslog.conf (would be better in /etc/rsyslog.d/afile):
$WorkDirectory /var/spool/rsyslog # where to place spool files
$ActionQueueFileName fwdRule1 # unique name prefix for spool files
$ActionQueueMaxDiskSpace 1g # 1gb space limit (use as much as possible)
$ActionQueueSaveOnShutdown on # save messages to disk on shutdown
$ActionQueueType LinkedList # run asynchronously
$ActionResumeRetryCount -1 # infinite retries if host is down
# Defines the fields of log data
$template ALI_LOG_FMT,"0.1 sys_tag %timegenerated:::date-unixtimestamp% %fromhost-ip% %hostname% %pri-text% %protocol-version% %app-name% %procid% %msgid% %msg:::drop-last-lf%\n"
*.* @@127.0.0.1:11111;ALI_LOG_FMT


Check if some ports have to be opened (security group)


Check how to enable logtail with systemd:
sudo /etc/init.d/ilogtaild stop
sudo /etc/init.d/ilogtaild start

Check if it is possible to configure a "Logtail Config" with Terraform, or at least with a Python script
--- TODO ---

The final step is to commit and push your changes to GitLab:
```bash
# Check files to commit
git status

# Add the modified and new files
git add infrastructure/05_vpc_slb_eip_domain/main.tf
git add infrastructure/10_webapp/15_ecs/main.tf
git add infrastructure/15_certman/10_ecs_slb_rule/main.tf

# Commit and push to GitLab
git commit -m "Collect logs into a log project."
git push origin master
```

--- TODO ---
TODO: add the modified Packer scripts
--- TODO ---

Check your CI / CD pipeline on GitLab, in particularly the logs of the "deploy" stage and make sure there is no error.

### Log search
Let's check the logging configuration. First we need to generate logs with the application.
One way to do that is to connect to the application (http://dev.my-sample-domain.xyz/) and create / delete tasks.

