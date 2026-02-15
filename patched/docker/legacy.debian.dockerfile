# This dockerfile is used for building a musl-based image for the legacy bundle
FROM mcr.microsoft.com/dotnet/sdk:6.0-alpine

RUN apk update && \
    apk add \
        g++ \
        cmake \
        clang \
        make \
        build-base linux-headers \
        wget

# Install .NET Core 3.1 runtime (needed for netcoreapp3.1 test targets)
RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --runtime dotnet --channel 3.1 --install-dir /usr/share/dotnet && \
    ./dotnet-install.sh --runtime aspnetcore --channel 3.1 --install-dir /usr/share/dotnet && \
    rm dotnet-install.sh

WORKDIR /project