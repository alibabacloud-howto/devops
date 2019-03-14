## Docker multi-stage build
## First stage: complete build environment
FROM maven:3.5.0-jdk-8-alpine AS builder
# add source code and pom.xml
ADD ./src src/
ADD ./pom.xml pom.xml
# package executable jar
RUN mvn clean package

## Second stage: minimal runtime environment
FROM openjdk:8-jdk-alpine
VOLUME /tmp
# copy jar from the first stage
COPY --from=builder target/container-service-sample-1.0.0.jar app.jar
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","app.jar"]