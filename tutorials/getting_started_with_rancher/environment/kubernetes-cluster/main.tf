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
resource "alicloud_vpc" "rancher_k8s_vpc" {
  name = "rancher-k8s-vpc"
  cidr_block = "192.168.0.0/16"
}

data "alicloud_zones" "az" {
  network_type = "Vpc"
  available_disk_category = "cloud_ssd"
}
resource "alicloud_vswitch" "rancher_k8s_vswitch_zone_0" {
  name = "rancher-k8s-vswitch-zone-0"
  availability_zone = "${data.alicloud_zones.az.zones.0.id}"
  cidr_block = "192.168.0.0/24"
  vpc_id = "${alicloud_vpc.rancher_k8s_vpc.id}"
}
resource "alicloud_vswitch" "rancher_k8s_vswitch_zone_1" {
  name = "rancher-k8s-vswitch-zone-1"
  availability_zone = "${data.alicloud_zones.az.zones.1.id}"
  cidr_block = "192.168.1.0/24"
  vpc_id = "${alicloud_vpc.rancher_k8s_vpc.id}"
}

// Security group
resource "alicloud_security_group" "rancher_security_group" {
  name = "rancher-k8s-security-group"
  vpc_id = "${alicloud_vpc.rancher_k8s_vpc.id}"
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

// NAT Gateway (necessary for the Kubernetes cluster)
resource "alicloud_nat_gateway" "rancher_k8s_nat_gateway" {
  name = "rancher-k8s-nat-gateway"
  vpc_id = "${alicloud_vpc.rancher_k8s_vpc.id}"
  specification = "Small"
}
resource "alicloud_eip" "rancher_k8s_nat_eip" {
  name = "rancher-k8s-nat-eip"
  bandwidth = 10
}
resource "alicloud_eip_association" "rancher_k8s_eip_association" {
  allocation_id = "${alicloud_eip.rancher_k8s_nat_eip.id}"
  instance_id = "${alicloud_nat_gateway.rancher_k8s_nat_gateway.id}"
}
resource "alicloud_snat_entry" "rancher_k8s_snat_entry_zone_0" {
  snat_table_id = "${alicloud_nat_gateway.rancher_k8s_nat_gateway.snat_table_ids}"
  source_vswitch_id = "${alicloud_vswitch.rancher_k8s_vswitch_zone_0.id}"
  snat_ip = "${alicloud_eip.rancher_k8s_nat_eip.ip_address}"
}
resource "alicloud_snat_entry" "rancher_k8s_snat_entry_zone_1" {
  snat_table_id = "${alicloud_nat_gateway.rancher_k8s_nat_gateway.snat_table_ids}"
  source_vswitch_id = "${alicloud_vswitch.rancher_k8s_vswitch_zone_1.id}"
  snat_ip = "${alicloud_eip.rancher_k8s_nat_eip.ip_address}"
}

// Kubernetes Cluster
data "alicloud_instance_types" "k8s_master_types_zone_0" {
  availability_zone = "${alicloud_vswitch.rancher_k8s_vswitch_zone_0.availability_zone}"
  cpu_core_count = "${var.master_instance_cpu_count}"
  memory_size = "${var.master_instance_ram_amount}"
}
data "alicloud_instance_types" "k8s_master_types_zone_1" {
  availability_zone = "${alicloud_vswitch.rancher_k8s_vswitch_zone_1.availability_zone}"
  cpu_core_count = "${var.master_instance_cpu_count}"
  memory_size = "${var.master_instance_ram_amount}"
}
data "alicloud_instance_types" "k8s_worker_types_zone_0" {
  availability_zone = "${alicloud_vswitch.rancher_k8s_vswitch_zone_0.availability_zone}"
  cpu_core_count = "${var.worker_instance_cpu_count}"
  memory_size = "${var.worker_instance_ram_amount}"
}
data "alicloud_instance_types" "k8s_worker_types_zone_1" {
  availability_zone = "${alicloud_vswitch.rancher_k8s_vswitch_zone_1.availability_zone}"
  cpu_core_count = "${var.worker_instance_cpu_count}"
  memory_size = "${var.worker_instance_ram_amount}"
}
resource "alicloud_cs_kubernetes" "rancher_k8s_cluster" {
  name = "rancher-k8s-cluster"
  vswitch_ids = [
    "${alicloud_vswitch.rancher_k8s_vswitch_zone_0.id}",
    "${alicloud_vswitch.rancher_k8s_vswitch_zone_1.id}",
    "${alicloud_vswitch.rancher_k8s_vswitch_zone_1.id}",
    // Note: the same VSwitch is used for 2 nodes, as several regions do not have 3 avalability zones
  ]
  new_nat_gateway = false

  master_instance_types = [
    "${data.alicloud_instance_types.k8s_master_types_zone_0.instance_types.0.id}",
    "${data.alicloud_instance_types.k8s_master_types_zone_1.instance_types.0.id}",
    "${data.alicloud_instance_types.k8s_master_types_zone_1.instance_types.0.id}",
  ]
  worker_instance_types = [
    "${data.alicloud_instance_types.k8s_worker_types_zone_0.instance_types.0.id}",
    "${data.alicloud_instance_types.k8s_worker_types_zone_1.instance_types.0.id}",
    "${data.alicloud_instance_types.k8s_worker_types_zone_1.instance_types.0.id}",
  ]
  master_disk_category = "cloud_ssd"
  worker_disk_category = "cloud_ssd"
  master_disk_size = "${var.master_instance_disk_size}"
  worker_disk_size = "${var.worker_instance_disk_size}"
  worker_numbers = [
    "${floor(var.worker_instance_count / 3)}",
    "${floor(var.worker_instance_count / 3)}",
    "${var.worker_instance_count - 2 * floor(var.worker_instance_count / 3)}"
  ]
  password = "${var.ecs_root_password}"
  enable_ssh = true

  cluster_network_type = "flannel"
  pod_cidr = "172.20.0.0/16"
  service_cidr = "172.21.0.0/20"

  depends_on = [
    "alicloud_snat_entry.rancher_k8s_snat_entry_zone_0",
    "alicloud_snat_entry.rancher_k8s_snat_entry_zone_1",
  ]
}