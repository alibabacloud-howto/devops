#!/usr/bin/env python
# coding=utf-8

import ConfigParser
import OpenSSL
import glob
import json
import os
import pytz
import shutil
import subprocess
from aliyunsdkcore.client import AcsClient
from aliyunsdkcore.request import CommonRequest
from datetime import datetime
from datetime import timedelta

# Read the configuration
config = ConfigParser.ConfigParser()
config.read("/etc/certificate-updater/config.ini")

accessKeyId = config.get("AlibabaCloud", "AccessKeyId")
accessKeySecret = config.get("AlibabaCloud", "AccessKeySecret")
regionId = config.get("AlibabaCloud", "RegionId")
environment = config.get("Environment", "Environment")
domain = config.get("Environment", "Domain")
subDomain = config.get("Environment", "SubDomain")
emailAddress = config.get("Environment", "EmailAddress")

print("Certificate Updater started (environment: " + environment + ", " +
      "domain: " + domain + ", sub-domain: " + subDomain + ", email address: " + emailAddress + ")")

# Check if we need to run certbot
certFolderPath = "/mnt/oss_bucket/certificate/" + environment + "/letsencrypt"
publicKeyPath = certFolderPath + "/cert.pem"
privateKeyPath = certFolderPath + "/privkey.pem"
certbotCertFolderPath = "/etc/letsencrypt/live/" + subDomain + "." + domain

publicKeyExists = os.path.exists(publicKeyPath)
privateKeyExists = os.path.exists(privateKeyPath)
certExpireSoon = False

if publicKeyExists:
    publicKey = open(publicKeyPath, "rt").read()
    x509 = OpenSSL.crypto.load_certificate(OpenSSL.crypto.FILETYPE_PEM, publicKey)
    expirationDate = datetime.strptime(x509.get_notAfter(), "%Y%m%d%H%M%SZ").replace(tzinfo=pytz.UTC)
    now = datetime.now(pytz.utc)
    certExpireSoon = now + timedelta(weeks=1) > expirationDate

runCertBot = not publicKeyExists or not privateKeyExists or certExpireSoon

certbotCronConfigured = not os.path.exists("/etc/cron.d/certbot")
print("Let's Encrypt certificate status:")
print("    publicKeyPath           = %s" % publicKeyPath)
print("    privateKeyPath          = %s" % privateKeyPath)
print("    publicKeyExists         = %s" % publicKeyExists)
print("    privateKeyExists        = %s" % privateKeyExists)
print("    certExpireSoon          = %s" % certExpireSoon)
print("    certbotCronConfigured   = %s" % certbotCronConfigured)
print("    runCertBot              = %s" % runCertBot)

# Run certbot if necessary
if runCertBot:
    print("Executing certbot...")
    returnCode = subprocess.call(
        "certbot certonly --webroot -w /var/www/html/certman/.well-known/ -d \"%s.%s\" --non-interactive "
        "--agree-tos --email \"%s\"" % (subDomain, domain, emailAddress), shell=True)
    if returnCode != 0:
        print("Unable to run certbot, quitting...")
        quit(1)

    print("Replace the certificate on the OSS bucket...")
    if not os.path.exists(certFolderPath):
        os.makedirs(certFolderPath)
    for f in glob.glob(certFolderPath + "/*"):
        os.remove(f)
    for f in glob.glob(certbotCertFolderPath + "/*"):
        shutil.copy2(f, certFolderPath + "/")

# Check if the SLB certificate needs to be updated
print("Getting information about the SLB sample-app-slb-" + environment + "...")
client = AcsClient(accessKeyId, accessKeySecret, regionId)
request = CommonRequest()
request.set_accept_format("json")
request.set_domain("slb.aliyuncs.com")
request.set_method("POST")
request.set_version("2014-05-15")
request.set_action_name("DescribeLoadBalancers")
request.add_query_param("LoadBalancerName", "sample-app-slb-" + environment)
request.add_query_param("RegionId", regionId)
jsonResponse = client.do_action_with_exception(request)
response = json.loads(jsonResponse)
if response["TotalCount"] != 1:
    print("Unable to find the SLB. Response:")
    print(response)
    quit(1)
slbInfo = response["LoadBalancers"]["LoadBalancer"][0]
slbId = slbInfo["LoadBalancerId"]

print("SLB found: %s. Loading HTTPS listener information..." % slbId)
request = CommonRequest()
request.set_accept_format("json")
request.set_domain("slb.aliyuncs.com")
request.set_method("POST")
request.set_version("2014-05-15")
request.set_action_name("DescribeLoadBalancerHTTPSListenerAttribute")
request.add_query_param("ListenerPort", "443")
request.add_query_param("LoadBalancerId", slbId)
jsonResponse = client.do_action_with_exception(request)
response = json.loads(jsonResponse)
if "ServerCertificateId" not in response:
    print("Unable to find the SLB HTTPS certificate. Response:")
    print(response)
    quit(1)
slbCertId = response["ServerCertificateId"]

print("SLB HTTPS listener information found. Loading information about the certificate " + slbCertId + "...")
request = CommonRequest()
request.set_accept_format("json")
request.set_domain("slb.aliyuncs.com")
request.set_method("POST")
request.set_version("2014-05-15")
request.set_action_name("DescribeServerCertificates")
request.add_query_param("RegionId", regionId)
request.add_query_param("ServerCertificateId", slbCertId)
jsonResponse = client.do_action_with_exception(request)
response = json.loads(jsonResponse)
if not response["ServerCertificates"]["ServerCertificate"]:
    print("Unable to find the certificate " + slbCertId + ". Response:")
    print(response)
    quit(1)
slbCertInfo = response["ServerCertificates"]["ServerCertificate"][0]
slbCertFingerprint = slbCertInfo["Fingerprint"].upper()

# Compute the fingerprint of the current certificate from Let's Encrypt
print("Computing the Let's Encrypt certificate fingerprint...")
publicKey = open(publicKeyPath, "rt").read()
x509 = OpenSSL.crypto.load_certificate(OpenSSL.crypto.FILETYPE_PEM, publicKey)
certFingerprint = x509.digest("sha1")

# Check if the SLB listener certificate needs to be updated
updateListenerCert = slbCertFingerprint != certFingerprint
print("Certificates information:")
print("    slbCertFingerprint = %s" % slbCertFingerprint)
print("    certFingerprint    = %s" % certFingerprint)
print("    updateListenerCert = %s" % updateListenerCert)

if not updateListenerCert:
    print("SLB listener certificate is up to date.")
    quit(0)

# Upload the SLB listener certificate
now = datetime.now()
certName = "sample-app-slb-certificate-" + environment + "-" + now.strftime("%Y%m%d%H%M%S")
print("Upload the Let's Encrypt certificate " + certName + "...")
request = CommonRequest()
request.set_accept_format("json")
request.set_domain("slb.aliyuncs.com")
request.set_method("POST")
request.set_version("2014-05-15")
request.set_action_name("UploadServerCertificate")
privateKey = open(privateKeyPath, "rt").read()
privateKey = privateKey.replace("BEGIN PRIVATE", "BEGIN RSA PRIVATE")
privateKey = privateKey.replace("END PRIVATE", "END RSA PRIVATE")
request.add_query_param("ServerCertificate", publicKey)
request.add_query_param("PrivateKey", privateKey)
request.add_query_param("ServerCertificateName", certName)
jsonResponse = client.do_action_with_exception(request)
response = json.loads(jsonResponse)
if not response["ServerCertificateId"]:
    print("Unable to upload the certificate " + certName + ". Response:")
    print(response)
    quit(1)
certId = response["ServerCertificateId"]

# Update the HTTPS listener with the new certificate
print("Certificate " + certName + " (id: " + certId + ") uploaded with success. Updating the HTTP listener...")
request = CommonRequest()
request.set_accept_format("json")
request.set_domain("slb.aliyuncs.com")
request.set_method("POST")
request.set_version("2014-05-15")
request.set_action_name("SetLoadBalancerHTTPSListenerAttribute")
request.add_query_param("ListenerPort", "443")
request.add_query_param("LoadBalancerId", slbId)
request.add_query_param("ServerCertificateId", certId)
jsonResponse = client.do_action_with_exception(request)
response = json.loads(jsonResponse)
if "Code" in response:
    print("Unable to update the SLB HTTPS certificate. Response:")
    print(response)
    quit(1)
print("SLB listener certificate updated with success.")
