---
layout: default
---
# DevOps for small / medium web apps - Part 5 - HTTPS configuration

## Summary
0. [Introduction](#introduction)
1. [Architecture](#architecture)
2. [SLB configuration](#slb-configuration)
3. [Certificate manager](#certificate-manager)

## Introduction
[HTTPS](https://en.wikipedia.org/wiki/HTTPS) is now a requirement for any professional
website that needs to receive input from users, as it prevents
[man-in-the-middle](https://en.wikipedia.org/wiki/Man-in-the-middle_attack) and
[eavesdropping](https://en.wikipedia.org/wiki/Eavesdropping) attacks.

There are several ways to configure HTTPS for our sample application, the easiest one is to
[buy a SSL/TLS certificate](https://www.alibabacloud.com/product/certificates) and
[upload it on our SLB](https://www.alibabacloud.com/help/doc-detail/32336.htm). However we will choose a
more complex approach by using SSL/TLS certificates from [Let’s Encrypt](https://letsencrypt.org/).

"Let’s Encrypt" is a certificate authority founded by organizations such as the
[Electronic Frontier Foundation](https://www.eff.org/), the
[Mozilla Foundation](https://en.wikipedia.org/wiki/Mozilla_Foundation) and [Cisco Systems](https://www.cisco.com/).
The advantages is that it's free and 100% automated, the main disadvantage is that it only provides
[Domain-Validated certificates](https://en.wikipedia.org/wiki/Domain-validated_certificate) (no
[Organization Validation](https://en.wikipedia.org/wiki/Public_key_certificate#Organization_validation) nor
[Extended Validation](https://en.wikipedia.org/wiki/Extended_Validation_Certificate)), which is enough for
many use cases.

## Architecture
HTTPS works by encrypting HTTP traffic via the [TLS protocol](https://en.wikipedia.org/wiki/Transport_Layer_Security).
In order to configure HTTPS, we first need to obtain a
[SSL/TLS certificate](https://en.wikipedia.org/wiki/Transport_Layer_Security#Digital_certificates) and configure it
on our SLB (by adding a [HTTPS listener](https://www.alibabacloud.com/help/doc-detail/86438.htm)).

Once configured, the SLB handles the HTTPS "complexities" and continue to communicate with backend servers via
unencrypted HTTP. A typical HTTPS request works like this:
* A user opens a HTTPS connection with our web application;
* The SLB uses its configured SSL/TLS certificate to establish a secured connection;
* The user sends a HTTPS request;
* The SLB converts the HTTPS request into a HTTP one (unencrypted) and sends it to one of the backend servers;
* The backend server receives the HTTP request (as usual) and sends back a HTTP response;
* The SLB converts the HTTP response into a HTTPS one (encrypted) and sends it to the user.

Configuring a HTTPS listener for our SLB is relatively easy (we will add a
[alicloud_slb_server_certificate](https://www.terraform.io/docs/providers/alicloud/r/slb_server_certificate.html) and a
new [alicloud_slb_listener](https://www.terraform.io/docs/providers/alicloud/r/slb_listener.html) in our Terraform
script). Unfortunately obtaining an SSL/TLS certificate from Let’s Encrypt requires us to modify our architecture:

![HA architecture with HTTPS](images/diagrams/ha-architecture-with-https.png)

Let's Encrypt needs a way to automatically check that our domain name belongs to us before providing us a certificate.
For that it uses the concept of a [challenge](https://certbot.eff.org/docs/challenges.html): first we need to setup a
program called [certbot](https://certbot.eff.org/) on our system, then execute this application so that it cans
communicate with Let's Encrypt servers, run a challenge and obtain the certificate. There are several types of
challenges, we will use the [HTTP-01 one](https://certbot.eff.org/docs/challenges.html#http-01-challenge) and include
it in the following process:
* Create a new ECS instance named "certificate manager" and configure the SLB via a
  [slb_rule](https://www.terraform.io/docs/providers/alicloud/r/slb_rule.html) so that every HTTP request with an URL
  that starts with "http://dev.my-sample-domain.xyz/.well-known/" is forwarded to this new ECS instance.
* On this new ECS instance, install certbot and [Nginx](https://www.nginx.com/), then configure the later to serve
  files from "/var/www/html/certman/.well-known/" via "http:/localhost:8080/.well-known/" (the SLB is already configured
  to accept HTTP requests from internet on the port 80 and to distribute them to backend servers on the port 8080).
* Execute Certbot like this:
  ```bash
  certbot certonly --webroot -w /var/www/html/certman/.well-known/ -d dev.my-sample-domain.xyz
  ```
  This command runs the "HTTP-01" challenge in the following way:
  * Certbot creates a file with a unique name in the folder "/var/www/html/certman/.well-known/acme-challenge/", so
    that Nginx cans serve this file with the URL path "/.well-known/acme-challenge/unique-name";
  * Certbot contacts the Let's Encrypt server and asks it the to make a HTTP request to this file with the URL 
    "http://dev.my-sample-domain.xyz/.well-known/acme-challenge/unique-name";
  * If the Let's Encrypt server succeed to download this file, it means that we own the domain name and passed
    the challenge.
    
  Once the challenge is passed, the Let's Encrypt server generates a SSL/TLS certificate and sends it to certbot. The
  later stores it in the [PEM format](https://en.wikipedia.org/wiki/Privacy-Enhanced_Mail) in the folder
  "/etc/letsencrypt/live/dev.my-sample-domain.xyz/".
  
  Note: beware that Let's Encrypt has [rate limits](https://letsencrypt.org/docs/rate-limits/), so we should take care
  to run certbot only when necessary.

## SLB configuration
Let's start by adding a listener to our SLB in order to let it manage HTTPS connections. For that we will generate a
temporary [self-signed certificate](https://en.wikipedia.org/wiki/Self-signed_certificate) and update our Terraform
script. 

Note: the complete project files with the modifications of this tutorial part are available in the
"sample-app/version4" folder.

Open "gitlab-ci-scripts/deploy/build_basis_infra.sh" and insert the following block before
`# Set values for Terraform variables`:
```bash
# Generate SSL/TLS certificate if it doesn't exist
export CERT_FOLDER_PATH=${BUCKET_LOCAL_PATH}/certificate/${ENV_NAME}/selfsigned
export CERT_PUBLIC_KEY_PATH=${CERT_FOLDER_PATH}/public.crt
export CERT_PRIVATE_KEY_PATH=${CERT_FOLDER_PATH}/private.key

mkdir -p ${CERT_FOLDER_PATH}
if [[ ! -f ${CERT_PUBLIC_KEY_PATH} ]]; then
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ${CERT_PRIVATE_KEY_PATH} \
    -out ${CERT_PUBLIC_KEY_PATH} \
    -subj "/C=CN/ST=Zhejiang/L=Hangzhou/O=Alibaba Cloud/OU=Project Delivery/CN=${SUB_DOMAIN_NAME}.${DOMAIN_NAME}"
fi
```
As you can see, we use [OpenSSL](https://www.openssl.org/) to generate the certificate that we store on the OSS bucket.
The certificate is composed of a public key "public.crt" and a private key "private.key". They are all in the
[PEM format](https://en.wikipedia.org/wiki/Privacy-Enhanced_Mail).

We then create two new Terraform variables at the end of "infrastructure/05_vpc_slb_eip_domain/variables.tf":
```hcl-terraform
variable "certificate_public_key_path" {
  description = "Path to the public key of the SSL/TLS certificate."
}

variable "certificate_private_key_path" {
  description = "Path to the private key of the SSL/TLS certificate."
}
```

Then we modify the script "gitlab-ci-scripts/deploy/build_basis_infra.sh" again by adding the following lines under
`export TF_VAR_domain_name=${DOMAIN_NAME}`:
```bash
export TF_VAR_certificate_public_key_path=${CERT_PUBLIC_KEY_PATH}
export TF_VAR_certificate_private_key_path=${CERT_PRIVATE_KEY_PATH}
```

Finally, we add the resources `alicloud_slb_server_certificate` and `alicloud_slb_listener` into
"infrastructure/05_vpc_slb_eip_domain/main.tf":
```hcl-terraform
// ...
// Server load balancer
resource "alicloud_slb" "app_slb" {
  // ...
}

// SLB server certificate
resource "alicloud_slb_server_certificate" "app_slb_certificate" {
  name = "sample-app-slb-certificate-self-${var.env}"
  server_certificate = "${file(var.certificate_public_key_path)}"
  private_key = "${file(var.certificate_private_key_path)}"
}

// SLB listeners
resource "alicloud_slb_listener" "app_slb_listener_http" {
  // ...
}
resource "alicloud_slb_listener" "app_slb_listener_https" {
  load_balancer_id = "${alicloud_slb.app_slb.id}"

  backend_port = 8080
  frontend_port = 443
  bandwidth = -1
  protocol = "https"
  ssl_certificate_id = "${alicloud_slb_server_certificate.app_slb_certificate.id}"
  tls_cipher_policy = "tls_cipher_policy_1_0"

  health_check = "on"
  health_check_type = "http"
  health_check_connect_port = 8080
  health_check_uri = "/health"
  health_check_http_code = "http_2xx"
}

// EIP
// ...
```
Note 0: an SLB can manage two types of certificate resources: server certificates and CA certificates. We only deal with
the first type (the second type can be used to authenticate users with
[client certificates](https://en.wikipedia.org/wiki/Client_certificate)).

Note 1: the HTTPS listener is very similar to the HTTP one, the main differences are the frontend port (443 instead
of 80) and the presence of the `ssl_certificate_id`.

Commit and push these changes to GitLab:
```bash
# Go to the project folder
cd ~/projects/todolist

# Check files to commit
git status

# Add the modified and new files
git add gitlab-ci-scripts/deploy/build_basis_infra.sh
git add infrastructure/05_vpc_slb_eip_domain/variables.tf
git add infrastructure/05_vpc_slb_eip_domain/main.tf

# Commit and push to GitLab
git commit -m "Add a SLB HTTPS listener."
git push origin master
```

Check your CI / CD pipeline on GitLab, in particularly the logs of the "deploy" stage and make sure there is no error.

You can then test the results from your computer with the following command:
```bash
# Check that the SLB is configured to accept HTTPS requests
curl https://dev.my-sample-domain.xyz/
```
The `curl` command should fail with the following error:
```
curl: (60) SSL certificate problem: self signed certificate
More details here: https://curl.haxx.se/docs/sslcerts.html

curl performs SSL certificate verification by default, using a "bundle"
 of Certificate Authority (CA) public keys (CA certs). If the default
 bundle file isn't adequate, you can specify an alternate file
 using the --cacert option.
If this HTTPS server uses a certificate signed by a CA represented in
 the bundle, the certificate verification probably failed due to a
 problem with the certificate (it might be expired, or the name might
 not match the domain name in the URL).
If you'd like to turn off curl's verification of the certificate, use
 the -k (or --insecure) option.
HTTPS-proxy has similar options --proxy-cacert and --proxy-insecure.
```
Which is normal because self-signed certificates are considered insecure (a hacker performing a man-in-the-middle
attack can generate its own self-signed certificate), but it validates that our SLB listener is configured for HTTPS.

Note: we can force curl to accept our self-signed certificate with the following command:
```bash
# Force curl to accept our self-signed certificate
curl -k https://dev.my-sample-domain.xyz/
```
The `curl` command should output something like this:
```
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>To-Do list</title>
    <link rel="stylesheet" href="css/index.css" media="screen">
</head>
<body>
<div id="react"></div>
<script src="built/bundle.js"></script>
</body>
</html>
```

## Certificate manager

TODO new variable 
  EMAIL_ADDRESS: "john.doe@example.org"