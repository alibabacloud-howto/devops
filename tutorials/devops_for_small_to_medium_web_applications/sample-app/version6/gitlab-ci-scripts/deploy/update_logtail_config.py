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
print("Update the Logtail configuration on the log project (environment = " + environment +
      ", region = " + regionId + ")")

endpoint = regionId + ".log.aliyuncs.com"
logProjectName = "sample-app-log-project-" + environment
logStoreName = "sample-app-log-store-" + environment
logtailConfigName = "sample-app-logtail-config-" + environment
logMachineGroupName = "sample-app-log-machine-group-" + environment

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

# Apply the configuration to the machine group
print("Apply the logtail configuration to the machine group", logMachineGroupName)
client.apply_config_to_machine_group(logProjectName, logtailConfigName, logMachineGroupName)
