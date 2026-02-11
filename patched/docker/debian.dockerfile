# FROM mcr.microsoft.com/dotnet/sdk:9.0.300-bookworm-slim

# # https://stackoverflow.com/questions/77498786/unable-to-locate-package-dotnet-sdk-8-0
# RUN wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
#     dpkg -i packages-microsoft-prod.deb && \
#     rm packages-microsoft-prod.deb
# RUN apt-get update && \
#     apt-get install -y \
#         dotnet-sdk-8.0 \
#         cmake \
#         clang \
#         make

# WORKDIR /project

# Use Bullseye (Debian 11) base — ships OpenSSL 1.1 which .NET Core 3.1 requires.
# Bookworm (Debian 12) only has OpenSSL 3.x, causing "No usable version of libssl" crashes.
FROM mcr.microsoft.com/dotnet/sdk:6.0-bullseye-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        cmake \
        clang \
        make \
        build-essential \
        wget

# Install .NET Core 3.1 runtime (needed for netcoreapp3.1 test targets)
RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --runtime dotnet --channel 3.1 --install-dir /usr/share/dotnet && \
    ./dotnet-install.sh --runtime aspnetcore --channel 3.1 --install-dir /usr/share/dotnet && \
    rm dotnet-install.sh

WORKDIR /project