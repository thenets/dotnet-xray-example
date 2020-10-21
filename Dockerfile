FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build-env
WORKDIR /app

# Copy csproj and restore as distinct layers
COPY *.csproj ./
RUN dotnet restore

# Copy everything else and build
COPY . ./
RUN dotnet publish -c Release -o out
COPY ./entrypoint.sh ./out/

# Build runtime image
FROM mcr.microsoft.com/dotnet/core/aspnet:3.1
WORKDIR /app
COPY --from=build-env /app/out .

RUN set -x \
    # Install AWS X-Ray Daemon
    && apt-get update \
    && apt-get install -y --no-install-recommends apt-transport-https curl ca-certificates wget \
    && apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && wget -q https://s3.us-east-2.amazonaws.com/aws-xray-assets.us-east-2/xray-daemon/aws-xray-daemon-3.x.deb \
    && dpkg -i aws-xray-daemon-3.x.deb \
    # Set permission
    && chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
