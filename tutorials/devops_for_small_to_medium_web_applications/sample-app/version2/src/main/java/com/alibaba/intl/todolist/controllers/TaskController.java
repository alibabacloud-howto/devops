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

import com.alibaba.intl.todolist.model.Task;
import com.alibaba.intl.todolist.repositories.TaskRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.stream.StreamSupport;

/**
 * Manage {@link Task}s.
 *
 * @author Alibaba Cloud
 */
@RestController
public class TaskController {

    private static final Logger LOGGER = LoggerFactory.getLogger(TaskController.class);
    private TaskRepository taskRepository;

    public TaskController(TaskRepository taskRepository) {
        this.taskRepository = taskRepository;
    }

    @RequestMapping("/tasks")
    public List<Task> findAll() {
        Iterable<Task> tasks = taskRepository.findAll();
        return StreamSupport.stream(tasks.spliterator(), false)
                .collect(Collectors.toList());
    }

    @RequestMapping(value = "/tasks", method = RequestMethod.POST)
    public ResponseEntity<Task> create(@RequestBody Task task) {
        LOGGER.info("Create a new task: {}", task);

        if (task == null || StringUtils.isEmpty(task.getDescription())) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(null);
        }
        if (StringUtils.isEmpty(task.getUuid())) {
            task.setUuid(UUID.randomUUID().toString());
        }
        Task savedTask = taskRepository.save(task);
        return ResponseEntity.ok(savedTask);
    }

    @RequestMapping(value = "/tasks/{uuid}", method = RequestMethod.DELETE)
    public ResponseEntity<Task> deleteByUuid(@PathVariable("uuid") String uuid) {
        LOGGER.info("Delete the task with the UUID: {}", uuid);

        Optional<Task> optionalTask = taskRepository.findById(uuid);

        if (!optionalTask.isPresent()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(null);
        }

        taskRepository.deleteById(uuid);

        Task removedTask = optionalTask.get();
        return ResponseEntity.ok(removedTask);
    }

}
