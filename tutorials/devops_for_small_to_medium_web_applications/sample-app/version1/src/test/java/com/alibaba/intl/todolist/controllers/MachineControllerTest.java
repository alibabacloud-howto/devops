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

import com.alibaba.intl.todolist.AbstractTest;
import com.alibaba.intl.todolist.model.Machine;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.github.tomakehurst.wiremock.client.WireMock;
import com.github.tomakehurst.wiremock.junit.WireMockRule;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Rule;
import org.junit.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.net.InetAddress;

import static com.github.tomakehurst.wiremock.client.WireMock.*;
import static org.junit.Assert.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Test the REST API behind "/machine".
 *
 * @author Alibaba Cloud
 */
public class MachineControllerTest extends AbstractTest {

    @Autowired
    private WebApplicationContext wac;

    private MockMvc mockMvc;

    @Rule
    public WireMockRule wireMockRule = new WireMockRule(8089);

    @BeforeClass
    public static void overrideConfiguration() {
        System.setProperty("ecs.instanceIdUrl", "http://localhost:8089/instance-id");
    }

    @Before
    public void setup() {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac).build();

        stubFor(WireMock.get(urlEqualTo("/instance-id"))
                .willReturn(aResponse()
                        .withBody("sample-instance-id")));
    }

    @Test
    public void testFind() throws Exception {
        ObjectMapper objectMapper = new ObjectMapper();

        String machineJson = mockMvc.perform(get("/machine"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        Machine machine = objectMapper.readValue(machineJson, Machine.class);

        assertEquals("sample-instance-id", machine.getInstanceId());
        String hostname = InetAddress.getLocalHost().getHostName();
        assertEquals(hostname, machine.getHostname());
    }

}
