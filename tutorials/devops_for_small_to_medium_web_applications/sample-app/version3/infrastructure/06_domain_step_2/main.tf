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

// Oversea domain record (oversea line = outside of Mainland China)
data "alicloud_dns_records" "app_record_overseas" {
  domain_name = "${var.domain_name}"
  type = "A"
  host_record_regex = "${var.sub_domain_name}"
  line = "oversea"
}

// Domain record (default routing = Mainland China)
resource "alicloud_dns_record" "app_record_default" {
  name = "${var.domain_name}"
  type = "A"
  host_record = "${var.sub_domain_name}"
  routing = "default"
  value = "${data.alicloud_dns_records.app_record_overseas.records.0.value}"
  ttl = 600
}

