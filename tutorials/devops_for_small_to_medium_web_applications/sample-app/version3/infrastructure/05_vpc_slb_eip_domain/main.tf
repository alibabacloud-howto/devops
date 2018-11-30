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

// Availability zones that support multi-AZ RDS
data "alicloud_zones" "multi_az" {
  available_resource_creation = "Rds"
  multi = true
}

// VPC
resource "alicloud_vpc" "app_vpc" {
  name = "simple-app-vpc-${var.env}"
  cidr_block = "192.168.0.0/16"
}

// One VSwitch per availability zone
resource "alicloud_vswitch" "app_vswitch_zone_0" {
  name = "sample-app-vswitch-zone-0-${var.env}"
  availability_zone = "${replace(data.alicloud_zones.multi_az.zones.0.id, "/MAZ[0-9]\\(([a-z]),[a-z]\\)/", "$1")}"
  cidr_block = "192.168.0.0/24"
  vpc_id = "${alicloud_vpc.app_vpc.id}"
}
resource "alicloud_vswitch" "app_vswitch_zone_1" {
  name = "sample-app-vswitch-zone-1-${var.env}"
  availability_zone = "${replace(data.alicloud_zones.multi_az.zones.0.id, "/MAZ[0-9]\\([a-z],([a-z])\\)/", "$1")}"
  cidr_block = "192.168.1.0/24"
  vpc_id = "${alicloud_vpc.app_vpc.id}"
}

// Security group and rule
resource "alicloud_security_group" "app_security_group" {
  name = "sample-app-security-group-${var.env}"
  description = "Sample web application security group (${var.env} environment)."
  vpc_id = "${alicloud_vpc.app_vpc.id}"
}
resource "alicloud_security_group_rule" "accept_8080_rule" {
  type = "ingress"
  ip_protocol = "tcp"
  nic_type = "intranet"
  policy = "accept"
  port_range = "8080/8080"
  priority = 1
  security_group_id = "${alicloud_security_group.app_security_group.id}"
  cidr_ip = "0.0.0.0/0"
}

// Server load balancer
resource "alicloud_slb" "app_slb" {
  name = "sample-app-slb-${var.env}"

  specification = "slb.s1.small"

  internet = false
  vswitch_id = "${alicloud_vswitch.app_vswitch_zone_0.id}"
}

// SLB listener
resource "alicloud_slb_listener" "app_slb_listener_http" {
  load_balancer_id = "${alicloud_slb.app_slb.id}"

  backend_port = 8080
  frontend_port = 80
  bandwidth = -1
  protocol = "http"

  health_check = "on"
  health_check_type = "http"
  health_check_connect_port = 8080
  health_check_uri = "/health"
  health_check_http_code = "http_2xx"
}

// EIP
resource "alicloud_eip" "app_eip" {
  name = "sample-app-eip-${var.env}"
  bandwidth = 10
}

// Bind the EIP to the SLB
resource "alicloud_eip_association" "app_eip_association" {
  allocation_id = "${alicloud_eip.app_eip.id}"
  instance_id = "${alicloud_slb.app_slb.id}"
}

// Domain record
resource "alicloud_dns_record" "app_record_oversea" {
  name = "${var.domain_name}"
  type = "A"
  host_record = "${var.sub_domain_name}"
  routing = "oversea"
  value = "${alicloud_eip.app_eip.ip_address}"
  ttl = 600
}