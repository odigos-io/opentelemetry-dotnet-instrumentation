FROM mcr.microsoft.com/dotnet/sdk:9.0.300-bookworm-slim

RUN wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y \
        g++ \
        cmake \
        clang \
        make


# Install .NET Core 8.0 runtime (needed for net8.0 test targets)
RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --runtime dotnet --channel 8.0 --install-dir /usr/share/dotnet && \
    ./dotnet-install.sh --runtime aspnetcore --channel 8.0 --install-dir /usr/share/dotnet && \
    rm dotnet-install.sh

WORKDIR /project