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

# 🚀 Recommended Fix: Use the official .NET 8 SDK image as your base
FROM mcr.microsoft.com/dotnet/sdk:8.0-bookworm-slim

# The base image already contains the .NET 8 SDK.
# The following steps only install the additional build dependencies.
# The 'wget', 'dpkg', and 'dotnet-sdk-8.0' installation lines are now removed.

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        cmake \
        clang \
        make

WORKDIR /project