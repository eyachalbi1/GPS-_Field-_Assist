FROM jenkins/jenkins:lts-jdk17

USER root

# Outils de base + Docker CLI + Python + Java + Flutter/Android SDK
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    python3 \
    python3-pip \
    openjdk-11-jdk \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    xz-utils \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI pour builder l'image backend
RUN curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# SonarScanner CLI
RUN curl -sSLo /tmp/sonar-scanner.zip \
    https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip && \
    unzip /tmp/sonar-scanner.zip -d /opt && \
    mv /opt/sonar-scanner-5.0.1.3006-linux /opt/sonar-scanner && \
    rm /tmp/sonar-scanner.zip
ENV PATH="/opt/sonar-scanner/bin:${PATH}"

# Flutter SDK (stable channel)
RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Android SDK (command-line tools)
RUN mkdir -p /opt/android-sdk/cmdline-tools && \
    cd /opt/android-sdk && \
    curl -O https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip && \
    unzip commandlinetools-linux-*.zip -d cmdline-tools && \
    rm commandlinetools-linux-*.zip

ENV ANDROID_SDK_ROOT="/opt/android-sdk"
ENV PATH="${ANDROID_SDK_ROOT}/cmdline-tools/bin:${ANDROID_SDK_ROOT}/platform-tools:${PATH}"

# Accept Android licences
RUN yes | sdkmanager --licenses || true

# Installer les plateformes Android nécessaires pour Flutter
RUN sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" || true

# Flutter doctor (vérifie l'installation)
RUN flutter doctor -v || true

USER jenkins

# Plugins Jenkins essentiels
RUN jenkins-plugin-cli --plugins \
    git \
    workflow-aggregator \
    docker-workflow \
    pipeline-stage-view \
    credentials-binding \
    sonar \
    jacoco
