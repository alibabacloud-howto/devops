package com.alibabacloud.howto;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.InetAddress;
import java.net.UnknownHostException;

/**
 * @author lingkun
 * @date 2018/12/27
 */
@RestController
@SpringBootApplication
public class ContainerServiceApplication {

    private static final Logger LOGGER = LoggerFactory.getLogger(ContainerServiceApplication.class);

    @GetMapping("/")
    public String welcome() {
        return getServerIP() + " says: Hello, Container Service!";
    }

    public static void main(String[] args) {
        SpringApplication.run(ContainerServiceApplication.class, args);
    }

    private String getServerIP() {
        InetAddress inetAddress = null;
        try {
            inetAddress = InetAddress.getLocalHost();
        } catch (UnknownHostException e) {
            LOGGER.warn("Unable to obtain the IP address of this server.", e);
        }

        if (inetAddress == null) {
            return "Docker server";
        }

        return inetAddress.getHostAddress();
    }

}
