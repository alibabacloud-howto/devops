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
package com.alibaba.intl.todolist;

import org.junit.BeforeClass;
import org.junit.runner.RunWith;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.junit4.SpringJUnit4ClassRunner;
import org.springframework.test.context.web.WebAppConfiguration;

/**
 * Common test configuration.
 *
 * @author Alibaba Cloud
 */
@RunWith(SpringJUnit4ClassRunner.class)
@ContextConfiguration(classes = {Application.class})
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@WebAppConfiguration
public abstract class AbstractTest {

    @BeforeClass
    public static void overrideConfiguration() {
        System.setProperty("spring.jpa.hibernate.ddl-auto", "create");
        System.setProperty("spring.datasource.url", "jdbc:h2:mem:");
        System.setProperty("spring.datasource.username", "sa");
        System.setProperty("spring.datasource.password", "");

        System.setProperty("ecs.instanceIdUrl", "http://localhost/dummy");
    }

}
