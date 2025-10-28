FROM gradle:8.14.0-jdk21 AS builder
WORKDIR /home/gradle/src
COPY --chown=gradle:gradle . .
ENV GRADLE_OPTS="-Dorg.gradle.vfs.watch=false -Dorg.gradle.daemon=false"

RUN --mount=type=secret,id=gpr_user \
    --mount=type=secret,id=gpr_key \
    test -s /run/secrets/gpr_user && test -s /run/secrets/gpr_key && \
    gradle clean bootJar -x test --no-daemon --info --stacktrace \
      -Pgpr.user="$(cat /run/secrets/gpr_user)" \
      -Pgpr.key="$(cat /run/secrets/gpr_key)"

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /home/gradle/src/build/libs/*.jar /app/app.jar
ENTRYPOINT ["java","-jar","/app/app.jar"]