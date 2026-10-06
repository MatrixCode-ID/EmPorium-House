# Match the engine host: upstream Alpine, SDK installed only in the build stage.
ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION} AS base
ARG TZ=UTC
RUN apk add --no-cache aspnetcore10-runtime icu-data-full tzdata krb5 \
    iputils traceroute nano
ENV TZ=${TZ} \
    ASPNETCORE_URLS=http://+:8080 \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    DOTNET_RUNNING_IN_CONTAINER=true
WORKDIR /app
EXPOSE 8080

FROM base AS build
RUN apk add --no-cache dotnet10-sdk
ARG BUILD_CONFIGURATION=Release
ARG APP_VERSION=1.0.0
WORKDIR /src/emporium-house
# The engine comes from the EmSys.* packages on nuget.org (version in Directory.Build.props).
COPY Directory.Build.props ./
COPY src/backend/EmPoriumHouse.Api/ src/backend/EmPoriumHouse.Api/
RUN dotnet publish src/backend/EmPoriumHouse.Api/EmPoriumHouse.Api.csproj \
    --configuration "$BUILD_CONFIGURATION" --output /publish \
    /p:UseAppHost=false /p:Version="$APP_VERSION"

FROM base AS final
RUN addgroup -S -g 1654 em && adduser -S -D -u 1654 -G em em \
    && mkdir -p /app/data && chown em:em /app/data
COPY --from=build /publish/ ./
USER em
ENTRYPOINT ["dotnet", "EmPoriumHouse.Api.dll"]
