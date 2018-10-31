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
package com.alibaba.intl.todolist.controllers;

import com.alibaba.intl.todolist.model.Machine;
import org.apache.commons.io.IOUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.InputStream;
import java.net.InetAddress;
import java.net.URL;
import java.net.URLConnection;
import java.nio.charset.Charset;

/**
 * Provide information about the {@link Machine} this application is currently running on.
 *
 * @author Alibaba Cloud
 */
@RestController
public class MachineController {
    private static final Logger LOGGER = LoggerFactory.getLogger(MachineController.class);

    @RequestMapping("/machine")
    public Machine find() {
        LOGGER.debug("Retrieve information about the current machine.");

        // Retrieve the instance ID from the ECS REST API
        String instanceId = "unknown";
        try {
            URL url = new URL("http://100.100.100.200/latest/meta-data/instance-id");
            URLConnection urlConnection = url.openConnection();
            urlConnection.setConnectTimeout(1000);
            urlConnection.setReadTimeout(1000);
            try (InputStream inputStream = urlConnection.getInputStream()) {
                instanceId = IOUtils.toString(inputStream, Charset.defaultCharset());
            }
        } catch (Exception e) {
            LOGGER.debug("Unable to retrieve the instanceId.", e);
        }

        // Retrieve the hostname
        String hostname = "unknown";
        try {
            hostname = InetAddress.getLocalHost().getHostName();
        } catch (Exception e) {
            LOGGER.warn("Unable to retrieve the hostname.", e);
        }

        return new Machine(hostname, instanceId);
    }

}
