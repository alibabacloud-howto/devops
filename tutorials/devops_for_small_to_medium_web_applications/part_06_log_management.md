---
layout: default
---
# DevOps for small / medium web apps - Part 6 - Log management

## Summary
0. [Introduction](#introduction)
1. [Architecture](#architecture)
2. [Infrastructure improvements](#infrastructure-improvements)
   1. [Cloud resources](#cloud-resources)
   2. [VM images](#vm-images)
   3. [Logtail configuration on the log store](#logtail-configuration-on-the-log-store)
   4. [CI/CD pipeline update](#ci/cd-pipeline-update)
3. [Log search](#log-search)

## Introduction
Working with application logs become more complex when the number of servers increase: for example when there is only
one server, an administrator just needs to connect to this machine and read the "/var/logs" folder and execute
commands such as `journalctl --unit=todo-list`. But when the number of servers increase, the same administrator
must connect to each machine in order to find the information he's looking for. This become even worse when auto-scaling
is enabled, because servers are automatically created and released.

A solution to this problem is to use the [Log Service](https://www.alibabacloud.com/product/log-service): its role
is to collect logs from servers and let administrators / developers to make search into them.

Note: please find the source code containing the changes of this part in the "sample-app/version5" folder.

## Architecture
Configuring Alibaba Cloud Log Service is a bit complex. The following diagram illustrates how it works:

![Log collection](images/diagrams/log-collection.png)

In this diagram we can see that in each ECS instance, an application is generating logs and sending them to 
[Rsyslog](https://en.wikipedia.org/wiki/Rsyslog) (this is the case of our java application, thanks to the
SystemD configuration file that specifies `StandardOutput=syslog` and `StandardError=syslog`).

Rsyslog then must be configured to forward the logs to
[Logtail](https://www.alibabacloud.com/help/doc-detail/28979.htm), a log collection agent similar to
[LogStash](https://www.elastic.co/products/logstash), responsible for sending logs to the Log Service (note: you can
read [this document](https://www.alibabacloud.com/help/doc-detail/44259.htm) if you are interested in a comparison
between these tools).

The Log Service is organized in [log projects](https://www.alibabacloud.com/help/doc-detail/48873.htm) that contains
[log stores](https://www.alibabacloud.com/help/doc-detail/48874.htm). In our case we just need one log project and one
log store. The Log Service provides endpoints (such as "http://logtail.ap-southeast-1-intranet.log.aliyuncs.com") in
each region for Logtail, but both the log store and logtail must be configured:
* Logtail needs a configuration to understand how to parse logs from Rsyslog (the fields / columns in each log line)
  and how to send them to the Log Service (the endpoint, buffer size, ...)
* A log store needs to be configured in order to know what are the logs that needs to be stored (e.g. from which data
  source).

The log store configuration uses the concept of a
[machine group](https://www.alibabacloud.com/help/doc-detail/28966.htm) that refers to the ECS instances that
send their logs via Logtail.

## Infrastructure improvements
### Cloud resources
The first step is to add a log project and a log store in our basis infrastructure. Open a terminal on your
computer and type:
```bash
# Go to the project folder
cd ~/projects/todolist

# Edit the basis infrastructure definition
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

We then need to create two machine groups: one for our application, one for our certificate manager.
Enter the following commands in your terminal:
```bash
# Edit the application infrastructure definition
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

Continue adding the machine group for the certificate manager:
```bash
# Edit the certificate manager infrastructure definition
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

### VM images
The next step is to modify our Packer scripts in order to install Logtail and configure it:
```bash
# Edit the application image script
nano infrastructure/10_webapp/10_image/app_image.json
```
Add the following provisioner at the end of the `provisioners` array:
```json
{
  "type": "shell",
  "inline": [
    "export REGION=\"{{user `region_id`}}\"",
    "wget \"http://logtail-release-${REGION}.oss-${REGION}.aliyuncs.com/linux64/logtail.sh\" -O logtail.sh",
    "chmod 755 logtail.sh",
    "./logtail.sh install auto",
    "export STREAMLOG_FORMATS=\"[{\\\"version\\\": \\\"0.1\\\", \\\"fields\\\": []}]\"",
    "export ESCAPED_STREAMLOG_FORMATS=$(echo $STREAMLOG_FORMATS | sed -e 's/\\\\/\\\\\\\\/g; s/\\//\\\\\\//g; s/&/\\\\\\&/g')",
    "sed -i \"s/\\(\\\"streamlog_open\\\" : \\).*\\$/\\1true,/\" /usr/local/ilogtail/ilogtail_config.json",
    "sed -i \"s/\\(\\\"streamlog_formats\\\":\\).*\\$/\\1${ESCAPED_STREAMLOG_FORMATS},/\" /usr/local/ilogtail/ilogtail_config.json"
  ]
}
```
Save and exit with CTRL+X. Then do the same with the certificate manager image:
```bash
# Edit the certificate manager image script
nano infrastructure/15_certman/05_image/certman_image.json
```
Add the same provisioner as above, then save and exit with CTRL+X.

We haven't finished with Packer scripts yet as we still need to configure Rsyslog to forward logs to Logtail.
```bash
# Create the Rsyslog configuration script
nano infrastructure/10_webapp/10_image/resources/rsyslog-logtail.conf
```
Enter the following content into this file:
```
$ActionQueueFileName fwdRule1 # unique name prefix for spool files
$ActionQueueMaxDiskSpace 1g # 1gb space limit (use as much as possible)
$ActionQueueSaveOnShutdown on # save messages to disk on shutdown
$ActionQueueType LinkedList # run asynchronously
$ActionResumeRetryCount -1 # infinite retries if host is down

# Defines the fields of log data
$template ALI_LOG_FMT,"0.1 sys_tag %timegenerated:::date-unixtimestamp% %fromhost-ip% %hostname% %pri-text% %protocol-version% %app-name% %procid% %msgid% %msg:::drop-last-lf%\n"
*.* @@127.0.0.1:11111;ALI_LOG_FMT
```
Save and exit by pressing CTRL+X. Copy the same file for the certificate manager:
```bash
# Copy the Rsyslog configuration script
cp infrastructure/10_webapp/10_image/resources/rsyslog-logtail.conf infrastructure/15_certman/05_image/resources/rsyslog-logtail.conf
```
Add a provisioner into the application Packer script in order to upload this configuration file:
```bash
# Edit the application image script
nano infrastructure/10_webapp/10_image/app_image.json
```
Add the following provisioner:
```json
{
  "type": "file",
  "source": "resources/rsyslog-logtail.conf",
  "destination": "/etc/rsyslog.d/80-logtail.conf"
}
```
Save and exit with CTRL+X. Edit in a similar way the certificate manager image script:
```bash
# Edit the certificate manager image script
nano infrastructure/15_certman/05_image/certman_image.json
```
Add the same provisioner as above then save and quit with CTRL+X.

### Logtail configuration on the log store
Unfortunately the Terraform provider for Alibaba Cloud doesn't support Logtail configuration on the log store side.
However we can still manage it automatically thanks to the
[OpenAPI services](https://www.alibabacloud.com/help/doc-detail/29042.htm).

There are several ways to call this API, one solution is to use the
[Python SDK](https://www.alibabacloud.com/help/doc-detail/29077.htm) to create a script that will be called by Gitlab:
```bash
# Create the Python script that will update the Logtail configuration on the log store side
nano gitlab-ci-scripts/deploy/update_logtail_config.py
```
Copy the following content into this file:
```python
#!/usr/bin/python3

import sys
from aliyun.log.logclient import LogClient
from aliyun.log.logexception import LogException
from aliyun.log.logtail_config_detail import SyslogConfigDetail

# Read the arguments
accessKeyId = sys.argv[1]
accessKeySecret = sys.argv[2]
regionId = sys.argv[3]
environment = sys.argv[4]
print("Update the Logtail configuration on the log store (environment = " + environment +
      ", region = " + regionId + ")")

endpoint = regionId + ".log.aliyuncs.com"
logProjectName = "sample-app-log-project-" + environment
logStoreName = "sample-app-log-store-" + environment
logtailConfigName = "sample-app-logtail-config-" + environment
appMachineGroupName = "sample-app-log-machine-group-" + environment
certmanMachineGroupName = "sample-app-certman-log-machine-group-" + environment

# Load the existing Logtail configuration
print("Loading existing Logtail configuration (endpoint = " + endpoint +
      ", logProjectName = " + logProjectName + ", logtailConfigName = " + logtailConfigName + ")...")

client = LogClient(endpoint, accessKeyId, accessKeySecret)
existingConfig = None
try:
    response = client.get_logtail_config(logProjectName, logtailConfigName)
    existingConfig = response.logtail_config
    print("Existing logtail configuration found: ", existingConfig.to_json())
except LogException:
    print("No existing logtail configuration found.")

# Create or update the logtail configuration
configDetail = SyslogConfigDetail(logstoreName=logStoreName, configName=logtailConfigName, tag="sys_tag")
if existingConfig is None:
    print("Create the logtail configuration:", configDetail.to_json())
    client.create_logtail_config(logProjectName, configDetail)
else:
    print("Update the logtail configuration:", configDetail.to_json())
    client.update_logtail_config(logProjectName, configDetail)

# Apply the configuration to machine groups
print("Apply the logtail configuration to the machine group", appMachineGroupName)
client.apply_config_to_machine_group(logProjectName, logtailConfigName, appMachineGroupName)
print("Apply the logtail configuration to the machine group", certmanMachineGroupName)
client.apply_config_to_machine_group(logProjectName, logtailConfigName, certmanMachineGroupName)
```
Save and quit by pressing CTRL+X.

### CI/CD pipeline update
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

## Log search
Let's check the logging configuration. First we need to generate logs with the application.
One way to do that is to connect to the application (http://dev.my-sample-domain.xyz/) and create / delete tasks.

