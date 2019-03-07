/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Minimal environment for running Gitlab Community Edition in Alibaba Cloud.

provider "alicloud" {}

// VPC and VSwitch
resource "alicloud_vpc" "vpc" {
  name = "cicdk8s-vpc"
  cidr_block = "172.16.0.0/12"
}

data "alicloud_zones" "az" {
  network_type = "Vpc"
  available_disk_category = "cloud_ssd"
}
resource "alicloud_vswitch" "vswitch" {
  name = "cicdk8s-gitlab-vswitch"
  availability_zone = "${data.alicloud_zones.az.zones.0.id}"
  cidr_block = "172.16.0.0/16"
  vpc_id = "${alicloud_vpc.vpc.id}"
}

// Security group and rules
resource "alicloud_security_group" "gitlab_security_group" {
  name = "cicdk8s-gitlab-security-group"
  vpc_id = "${alicloud_vpc.vpc.id}"
}
resource "alicloud_security_group_rule" "gitlab_rule_ssh" {
  security_group_id = "${alicloud_security_group.gitlab_security_group.id}"
  type = "ingress"
  ip_protocol = "tcp"
  nic_type = "intranet"
  policy = "accept"
  port_range = "22/22"
  priority = 1
  cidr_ip = "0.0.0.0/0"
}
resource "alicloud_security_group_rule" "gitlab_rule_http" {
  security_group_id = "${alicloud_security_group.gitlab_security_group.id}"
  type = "ingress"
  ip_protocol = "tcp"
  nic_type = "intranet"
  policy = "accept"
  port_range = "80/80"
  priority = 1
  cidr_ip = "0.0.0.0/0"
}

// ECS instances
data "alicloud_images" "ubuntu_images" {
  name_regex = "^ubuntu_16.*_64"
  most_recent = true
  owners = "system"
}
data "alicloud_instance_types" "gitlab_instance_types" {
  availability_zone = "${alicloud_vswitch.vswitch.availability_zone}"
  cpu_core_count = 2
  memory_size = 4
}
resource "alicloud_instance" "gitlab_instance" {
  instance_name = "cicdk8s-gitlab-instance"
  image_id = "${data.alicloud_images.ubuntu_images.images.0.id}"
  availability_zone = "${alicloud_vswitch.vswitch.availability_zone}"
  system_disk_category = "cloud_ssd"
  system_disk_size = 40
  instance_type = "${data.alicloud_instance_types.gitlab_instance_types.instance_types.0.id}"
  security_groups = [
    "${alicloud_security_group.gitlab_security_group.id}"
  ]
  vswitch_id = "${alicloud_vswitch.vswitch.id}"
  internet_max_bandwidth_out = 10
  password = "${var.gitlab_instance_password}"

  provisioner "remote-exec" {
    script = "install_gitlab.sh"
    connection {
      type = "ssh"
      user = "root"
      password = "${alicloud_instance.gitlab_instance.password}"
      host = "${alicloud_instance.gitlab_instance.public_ip}"
    }
  }
}
resource "alicloud_instance" "gitlab_runner_instance" {
  instance_name = "cicdk8s-gitlab-runner-instance"
  image_id = "${data.alicloud_images.ubuntu_images.images.0.id}"
  availability_zone = "${alicloud_vswitch.vswitch.availability_zone}"
  system_disk_category = "cloud_ssd"
  system_disk_size = 40
  instance_type = "${data.alicloud_instance_types.gitlab_instance_types.instance_types.0.id}"
  security_groups = [
    "${alicloud_security_group.gitlab_security_group.id}"
  ]
  vswitch_id = "${alicloud_vswitch.vswitch.id}"
  internet_max_bandwidth_out = 10
  password = "${var.gitlab_instance_password}"

  provisioner "remote-exec" {
    script = "install_runner.sh"
    connection {
      type = "ssh"
      user = "root"
      password = "${alicloud_instance.gitlab_runner_instance.password}"
      host = "${alicloud_instance.gitlab_runner_instance.public_ip}"
    }
  }
}