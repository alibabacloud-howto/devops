---
layout: default
---
{% raw  %}
# DevOps for small / medium web apps - Part 0 - General introduction

## Summary
0. [Introduction](#introduction)
1. [Prerequisite](#prerequisite)

## Introduction
The intended audience of this document are independent development teams that need to develop and maintain
a small / medium web application on Alibaba Cloud. The goal is to keep things simple: necessary
technologies and good practices are introduced step by step. More complex tooling is mentioned near the middle of this
tutorial, for example [infrastructure as code tools](https://en.wikipedia.org/wiki/Infrastructure_as_Code) are
explained in the [part 4](part_04_continuous_delivery.md).

The sample web application that comes with this tutorial is composed of two parts:
* A backend written in Java with [Spring Boot](https://spring.io/projects/spring-boot).
* A frontend written in Javascript with [React](https://reactjs.org/).

This document addresses the following points:
* How to automate compilation, testing, code analysis and packaging with a
  [CI pipeline](https://en.wikipedia.org/wiki/Continuous_integration).
* How to extend this pipeline in order to
  [deploy the application automatically](https://en.wikipedia.org/wiki/Continuous_delivery).
* How to setup a highly-available architecture on Alibaba Cloud.
* How to backup periodically (and restore!) the database and
  the [version control system](https://en.wikipedia.org/wiki/Version_control).
* How to upgrade the application and the database.
* How to centralize logs and monitor your cluster.

## Prerequisite
In order to follow this tutorial, please familiarize yourself with [Git](https://git-scm.com/) and install it on your
computer.

In addition, make sure you [have an Alibaba Cloud account](https://www.alibabacloud.com/help/doc-detail/50482.htm).

Important: please download the 
[related resources](https://github.com/alibabacloud-howto/devops/tree/master/tutorials/devops_for_small_to_medium_web_applications)
before moving to the next part.
{% endraw %}