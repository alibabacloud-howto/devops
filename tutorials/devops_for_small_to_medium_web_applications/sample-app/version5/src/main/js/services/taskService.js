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

const rest = require('rest');
const mime = require('rest/interceptor/mime');
const errorCode = require('rest/interceptor/errorCode');
const Task = require('../model/Task');

const taskService = {

    /**
     * Find all tasks from the server.
     *
     * @return {Promise.<Array.<Task>>}
     */
    findAll() {
        return new Promise((resolve, reject) => {
            const client = rest
                .wrap(mime)
                .wrap(errorCode);

            client({path: '/tasks'}).then(
                response => {
                    /** @type {Array} */
                    const taskProperties = response.entity;
                    const tasks = taskProperties.map(properties => new Task(properties));
                    resolve(tasks);
                },
                response => {
                    reject(response);
                });
        });
    },

    /**
     * Create the given {@link Task}.
     *
     * @param {Task} task
     * @return {Promise.<Task>}
     */
    create(task) {
        return new Promise((resolve, reject) => {
            const client = rest
                .wrap(mime)
                .wrap(errorCode);

            client({
                path: '/tasks',
                entity: task,
                headers: {'Content-Type': 'application/json'}
            }).then(
                response => {
                    const taskProperties = response.entity;
                    const task = new Task(taskProperties);
                    resolve(task);
                },
                response => {
                    reject(response);
                });
        });
    },

    /**
     * Delete the {@link Task} with the given UUID.
     *
     * @param {string} uuid
     * @return {Promise.<Task>}
     */
    deleteByUuid(uuid) {
        return new Promise((resolve, reject) => {
            const client = rest
                .wrap(mime)
                .wrap(errorCode);

            client({path: '/tasks/' + uuid, method: 'DELETE'}).then(
                response => {
                    const taskProperties = response.entity;
                    const task = new Task(taskProperties);
                    resolve(task);
                },
                response => {
                    reject(response);
                });
        });
    }
};

module.exports = taskService;