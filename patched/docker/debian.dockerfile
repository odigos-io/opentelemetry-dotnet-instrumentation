FROM mcr.microsoft.com/dotnet/sdk:6.0-bullseye-slim

RUN apt-get update && \
    apt-get install -y \
        cmake \
        clang \
        make \
        g++

# Install older sdks using the install script as there are no arm64 SDK packages.
RUN curl -sSL https://dot.net/v1/dotnet-install.sh --output dotnet-install.sh \
    && chmod +x ./dotnet-install.sh \
    && ./dotnet-install.sh -v 8.0.404 --install-dir /usr/share/dotnet --no-path \
    && rm dotnet-install.sh

WORKDIR /project
