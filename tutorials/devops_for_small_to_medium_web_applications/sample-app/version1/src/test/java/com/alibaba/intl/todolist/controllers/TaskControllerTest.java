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
import com.alibaba.intl.todolist.model.Task;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.Before;
import org.junit.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.util.Arrays;
import java.util.UUID;

import static org.junit.Assert.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Test the REST API behind "/tasks".
 *
 * @author Alibaba Cloud
 */
public class TaskControllerTest extends AbstractTest {

    @Autowired
    private WebApplicationContext wac;

    private MockMvc mockMvc;

    @Before
    public void setup() {
        mockMvc = MockMvcBuilders.webAppContextSetup(wac).build();
    }

    /**
     * Create 3 tasks, check it worked with findAll, then delete one task and check it worked.
     */
    @Test
    public void testCreateDeleteAndFindAll() throws Exception {
        ObjectMapper objectMapper = new ObjectMapper();

        // Create 3 tasks
        String uuid1 = UUID.randomUUID().toString();
        String uuid2 = UUID.randomUUID().toString();
        String uuid3 = UUID.randomUUID().toString();
        String task1 = "{\"uuid\": \"" + uuid1 + "\", \"description\": \"Task 1\"}";
        String task2 = "{\"uuid\": \"" + uuid2 + "\", \"description\": \"Task 2\"}";
        String task3 = "{\"uuid\": \"" + uuid3 + "\", \"description\": \"Task 3\"}";
        String createdTaskJson1 = mockMvc.perform(post("/tasks")
                .content(task1)
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String createdTaskJson2 = mockMvc.perform(post("/tasks")
                .content(task2)
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String createdTaskJson3 = mockMvc.perform(post("/tasks")
                .content(task3)
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        Task createdTask1 = objectMapper.readValue(createdTaskJson1, Task.class);
        Task createdTask2 = objectMapper.readValue(createdTaskJson2, Task.class);
        Task createdTask3 = objectMapper.readValue(createdTaskJson3, Task.class);
        assertEquals(uuid1, createdTask1.getUuid());
        assertEquals(uuid2, createdTask2.getUuid());
        assertEquals(uuid3, createdTask3.getUuid());
        assertEquals("Task 1", createdTask1.getDescription());
        assertEquals("Task 2", createdTask2.getDescription());
        assertEquals("Task 3", createdTask3.getDescription());

        // Check all the tasks
        String tasksJson = mockMvc.perform(get("/tasks"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        Task[] foundTasks = objectMapper.readValue(tasksJson, Task[].class);
        Task foundTask1 = Arrays.stream(foundTasks)
                .filter(t -> uuid1.equals(t.getUuid()))
                .findAny().orElse(null);
        Task foundTask2 = Arrays.stream(foundTasks)
                .filter(t -> uuid2.equals(t.getUuid()))
                .findAny().orElse(null);
        Task foundTask3 = Arrays.stream(foundTasks)
                .filter(t -> uuid3.equals(t.getUuid()))
                .findAny().orElse(null);
        assertNotNull(foundTask1);
        assertNotNull(foundTask2);
        assertNotNull(foundTask3);
        assertEquals("Task 1", foundTask1.getDescription());
        assertEquals("Task 2", foundTask2.getDescription());
        assertEquals("Task 3", foundTask3.getDescription());

        // Delete the task 2
        String deletedTaskJson = mockMvc.perform(delete("/tasks/" + uuid2))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        Task deletedTask = objectMapper.readValue(deletedTaskJson, Task.class);
        assertEquals(uuid2, deletedTask.getUuid());
        assertEquals("Task 2", deletedTask.getDescription());

        // Check the task has been effectively deleted
        tasksJson = mockMvc.perform(get("/tasks"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        foundTasks = objectMapper.readValue(tasksJson, Task[].class);
        foundTask1 = Arrays.stream(foundTasks)
                .filter(t -> uuid1.equals(t.getUuid()))
                .findAny().orElse(null);
        foundTask2 = Arrays.stream(foundTasks)
                .filter(t -> uuid2.equals(t.getUuid()))
                .findAny().orElse(null);
        foundTask3 = Arrays.stream(foundTasks)
                .filter(t -> uuid3.equals(t.getUuid()))
                .findAny().orElse(null);
        assertNotNull(foundTask1);
        assertNull(foundTask2);
        assertNotNull(foundTask3);
    }
}
