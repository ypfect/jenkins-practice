FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
ARG JAR_FILE=app.jar
COPY ${JAR_FILE} app.jar
EXPOSE 18080
ENTRYPOINT ["java", "-jar", "app.jar"]
