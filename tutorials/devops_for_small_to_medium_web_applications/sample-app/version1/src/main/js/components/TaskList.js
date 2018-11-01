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

const React = require('react');
const TaskListItem = require('./TaskListItem');
const TaskForm = require('./TaskForm');
const taskService = require('../services/taskService');

class TaskList extends React.Component {

    constructor(props) {
        super(props);
        this.state = {tasks: []};
    }

    componentDidMount() {
        taskService.findAll()
            .then(tasks => {
                this.setState({tasks: tasks});
            })
            .catch(error => {
                console.error(`Unable to find all the tasks: ${JSON.stringify(error)}`);
            });
    }

    /**
     * @param {string} taskUuid
     */
    deleteTask(taskUuid) {
        taskService.deleteByUuid(taskUuid)
            .then(task => {
                const newTasks = this.state.tasks.filter(t => t.uuid !== task.uuid);
                this.setState({tasks: newTasks});
            })
            .catch(error => {
                console.error(`Unable to delete the task ${taskUuid}: ${JSON.stringify(error)}`);
            });
    }

    /**
     * @param {Task} task
     */
    createTask(task) {
        taskService.create(task)
            .then(task => {
                const newTasks = this.state.tasks.concat([task]);
                this.setState({tasks: newTasks});
            })
            .catch(error => {
                console.error(`Unable to create the task ${JSON.stringify(task)}: ${JSON.stringify(error)}`);
            });
    }

    render() {
        const items = this.state.tasks.map(task =>
            <TaskListItem key={task.uuid} description={task.description} onClick={() => this.deleteTask(task.uuid)}/>
        );

        return (
            <div id="task-list">
                <h1>Tasks</h1>

                <h2>Add a new task</h2>
                <TaskForm onSubmit={task => this.createTask(task)}/>

                <h2>Existing tasks</h2>
                <table>
                    <tbody>
                    <tr>
                        <th>Description</th>
                        <th className="task-list-actions">&nbsp;</th>
                    </tr>
                    {items}
                    </tbody>
                </table>
            </div>
        );
    }
}

module.exports = TaskList;