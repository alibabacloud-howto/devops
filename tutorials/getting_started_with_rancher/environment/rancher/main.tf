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

// Alibaba Cloud provider (source: https://github.com/terraform-providers/terraform-provider-alicloud)
provider "alicloud" {}

// VPC and VSwitch
resource "alicloud_vpc" "rancher_vpc" {
  name = "rancher-vpc"
  cidr_block = "192.168.0.0/16"
}

data "alicloud_zones" "az" {
  network_type = "Vpc"
  available_disk_category = "cloud_ssd"
}
resource "alicloud_vswitch" "rancher_vswitch" {
  name = "rancher-vswitch"
  availability_zone = "${data.alicloud_zones.az.zones.0.id}"
  cidr_block = "192.168.0.0/24"
  vpc_id = "${alicloud_vpc.rancher_vpc.id}"
}

// Security group
resource "alicloud_security_group" "rancher_security_group" {
  name = "rancher-security-group"
  vpc_id = "${alicloud_vpc.rancher_vpc.id}"
}
resource "alicloud_security_group_rule" "accept_22_rule" {
  type = "ingress"
  ip_protocol = "tcp"
  nic_type = "intranet"
  policy = "accept"
  port_range = "22/22"
  priority = 1
  security_group_id = "${alicloud_security_group.rancher_security_group.id}"
  cidr_ip = "0.0.0.0/0"
}
resource "alicloud_security_group_rule" "accept_80_rule" {
  type = "ingress"
  ip_protocol = "tcp"
  nic_type = "intranet"
  policy = "accept"
  port_range = "80/80"
  priority = 1
  security_group_id = "${alicloud_security_group.rancher_security_group.id}"
  cidr_ip = "0.0.0.0/0"
}
resource "alicloud_security_group_rule" "accept_443_rule" {
  type = "ingress"
  ip_protocol = "tcp"
  nic_type = "intranet"
  policy = "accept"
  port_range = "443/443"
  priority = 1
  security_group_id = "${alicloud_security_group.rancher_security_group.id}"
  cidr_ip = "0.0.0.0/0"
}

// ECS instance
data "alicloud_images" "ubuntu_images" {
  owners = "system"
  name_regex = "ubuntu_16[a-zA-Z0-9_]+64"
  most_recent = true
}
data "alicloud_instance_types" "instance_types" {
  cpu_core_count = 2
  memory_size = 4
  availability_zone = "${alicloud_vswitch.rancher_vswitch.availability_zone}"
  network_type = "Vpc"
}
resource "alicloud_instance" "rancher_ecs" {
  instance_name = "rancher-ecs"

  host_name = "rancher-ecs"
  password = "${var.ecs_root_password}"

  image_id = "${data.alicloud_images.ubuntu_images.images.0.id}"
  instance_type = "${data.alicloud_instance_types.instance_types.instance_types.0.id}"
  system_disk_category = "cloud_ssd"

  vswitch_id = "${alicloud_vswitch.rancher_vswitch.id}"
  security_groups = [
    "${alicloud_security_group.rancher_security_group.id}"
  ]
}

// EIP and binding to the ECS instance
resource "alicloud_eip" "rancher_eip" {
  name = "rancher-eip"
  bandwidth = 10
}

resource "alicloud_eip_association" "rancher_eip_association" {
  allocation_id = "${alicloud_eip.rancher_eip.id}"
  instance_id = "${alicloud_instance.rancher_ecs.id}"

  // Run the installation script after the EIP is bound to the ECS instance
  provisioner "remote-exec" {
    connection {
      host = "${alicloud_eip.rancher_eip.ip_address}"
      user = "root"
      password = "${var.ecs_root_password}"
    }
    script = "install_rancher.sh"
  }
}