---
layout: default
---
# DevOps for small / medium web apps - Part 5 - HTTPS configuration

## Summary
0. [Introduction](#introduction)
1. [Architecture](#architecture)
2. Certification server
3. SLB configuration
4. Pipeline improvement

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
[Domain-validated certificates](https://en.wikipedia.org/wiki/Domain-validated_certificate) (no
[Organization Validation](https://en.wikipedia.org/wiki/Public_key_certificate#Organization_validation) nor
[Extended Validation](https://en.wikipedia.org/wiki/Extended_Validation_Certificate)), which is enough for
many use cases.

## Architecture
