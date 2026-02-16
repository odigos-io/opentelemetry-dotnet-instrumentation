# # This dockerfile is used for building a musl-based image for the legacy bundle
# FROM mcr.microsoft.com/dotnet/sdk:6.0-alpine3.18

# # RUN apk update && \
# #     apk add \
# #         g++ \
# #         cmake \
# #         clang \
# #         make \
# #         build-base linux-headers \
# #         wget bash

# RUN apk add --no-cache \
#     bash wget \
#     g++ cmake clang make build-base linux-headers \
#     icu-libs krb5-libs zlib libgcc libstdc++ \
#     openssl1.1-compat


# # Install .NET Core 3.1 runtime (needed for netcoreapp3.1 test targets)
# RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
#     chmod +x dotnet-install.sh && \
#     ./dotnet-install.sh --runtime dotnet --channel 3.1 --install-dir /usr/share/dotnet && \
#     ./dotnet-install.sh --runtime aspnetcore --channel 3.1 --install-dir /usr/share/dotnet && \
#     rm dotnet-install.sh

# WORKDIR /project
FROM mcr.microsoft.com/dotnet/sdk:6.0-alpine3.16
ARG TARGETARCH

RUN apk update \
    && apk upgrade \
    && apk add --no-cache --update \
        ca-certificates \
        icu-libs icu-data-full \
        clang \
        cmake \
        make \
        curl \
        bash \
        alpine-sdk \
        protobuf \
        protobuf-dev \
        grpc

RUN update-ca-certificates
        
ENV IsAlpine=true
ENV PROTOBUF_PROTOC=/usr/bin/protoc
ENV gRPC_PluginFullPath=/usr/bin/grpc_csharp_plugin

# Install older .NET SDKs using the install script
RUN curl -sSL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh \
 && chmod +x dotnet-install.sh \
 && if [ "$TARGETARCH" = "amd64" ]; then \
      ./dotnet-install.sh -c 3.1 --install-dir /usr/share/dotnet --no-path ; \
    else \
      ./dotnet-install.sh --runtime dotnet --channel 3.1 --install-dir /usr/share/dotnet --no-path ; \
    fi \
 && rm dotnet-install.sh

WORKDIR /project