#!/usr/bin/env bash

#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

apt-get -y update
apt-get -y install curl

cd /tmp
curl -LO https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh
bash /tmp/script.deb.sh

apt-get -y install gitlab-ce

cp /etc/gitlab/gitlab.rb /etc/gitlab/gitlab.rb.bak
export PUBLIC_IP_ADDRESS=$(dig +short myip.opendns.com @resolver1.opendns.com)
sed "s,external_url 'http://gitlab.example.com',external_url 'http://$PUBLIC_IP_ADDRESS',g" /etc/gitlab/gitlab.rb >> /etc/gitlab/gitlab.rb.tmp
rm -f /etc/gitlab/gitlab.rb
mv /etc/gitlab/gitlab.rb.tmp /etc/gitlab/gitlab.rb

gitlab-ctl reconfigure
