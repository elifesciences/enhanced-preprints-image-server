ARG CANTALOUPE_VERSION=5.0.5

# Build
FROM ubuntu:22.04@sha256:aabed3296a3d45cede1dc866a24476c4d7e093aa806263c27ddaadbdce3c1054 as build

ARG DEBIAN_FRONTEND=noninteractive
ARG CANTALOUPE_VERSION

# Install various dependencies:
# * ca-certificates is needed by wget
# * ffmpeg is needed by FfmpegProcessor
# * wget download stuffs in this dockerfile
# * libopenjp2-tools is needed by OpenJpegProcessor
# * All the rest is needed by GrokProcessor
RUN apt-get update
RUN apt-get install -y --no-install-recommends \
    openjdk-11-jdk-headless \
    ffmpeg \
    maven \
    wget \
    libopenjp2-tools \
            liblcms2-dev \
            libpng-dev \
            libzstd-dev \
            libtiff-dev \
            libjpeg-dev \
            zlib1g-dev \
            libwebp-dev \
            libimage-exiftool-perl \
            curl \
            unzip \
            patch

# Grab source code and patch
RUN curl --silent --fail -OL https://github.com/cantaloupe-project/cantaloupe/archive/refs/tags/v$CANTALOUPE_VERSION.zip
RUN unzip v$CANTALOUPE_VERSION.zip
RUN mv cantaloupe-$CANTALOUPE_VERSION cantaloupe-src


# Install TurboJpegProcessor dependencies
RUN mkdir -p /opt/libjpeg-turbo/lib
RUN cp -r cantaloupe-src/docker/Linux-JDK11/image_files/libjpeg-turbo/lib64 /opt/libjpeg-turbo/lib

# Install KakaduNativeProcessor dependencies
RUN cp cantaloupe-src/dist/deps/Linux-x86-64/lib/* /usr/lib/

# Install various other dependencies that aren't in apt
# Install GrokProcessor dependencies
RUN wget -q https://github.com/GrokImageCompression/grok/releases/download/v7.6.5/libgrokj2k1_7.6.5-1_amd64.deb
RUN wget -q https://github.com/GrokImageCompression/grok/releases/download/v7.6.5/grokj2k-tools_7.6.5-1_amd64.deb
RUN dpkg -i ./libgrokj2k1_7.6.5-1_amd64.deb
RUN dpkg -i --ignore-depends=libjpeg62-turbo ./grokj2k-tools_7.6.5-1_amd64.deb

# Add our patches to the source
COPY ./patches ./
RUN cd cantaloupe-src/ && patch -p1 < /add-WebIdentityTokenFileCredentialsProvider-to-credentials-chain.patch

# Install application dependencies
RUN cd cantaloupe-src/ && mvn --quiet dependency:resolve

# Build
RUN cd cantaloupe-src/ && mvn clean package -DskipTests



# Package
FROM ubuntu:22.04@sha256:aabed3296a3d45cede1dc866a24476c4d7e093aa806263c27ddaadbdce3c1054
LABEL org.opencontainers.image.source="https://github.com/elifesciences/enhanced-preprints-image-server"

ARG CANTALOUPE_VERSION
ENV CANTALOUPE_VERSION=$CANTALOUPE_VERSION

EXPOSE 8182

# Update packages and install tools
RUN apt-get update -qy && apt-get dist-upgrade -qy && \
    apt-get install -qy --no-install-recommends curl imagemagick \
    libopenjp2-tools ffmpeg unzip default-jre-headless && \
    apt-get -qqy autoremove && apt-get -qqy autoclean

# Run non privileged
RUN adduser --system cantaloupe

# Get and unpack Cantaloupe release archive

COPY --from=build /cantaloupe-src/target/cantaloupe-$CANTALOUPE_VERSION.zip ./opt
RUN cd /opt \
    && unzip cantaloupe-$CANTALOUPE_VERSION.zip \
    && ln -s cantaloupe-$CANTALOUPE_VERSION cantaloupe \
    && rm cantaloupe-$CANTALOUPE_VERSION.zip \
    && mkdir -p /var/log/cantaloupe /var/cache/cantaloupe \
    && cp -rs /opt/cantaloupe/deps/Linux-x86-64/* /usr/

COPY cantaloupe.properties /opt/cantaloupe/

RUN chown -R cantaloupe /opt/cantaloupe-$CANTALOUPE_VERSION /var/log/cantaloupe /var/cache/cantaloupe



USER cantaloupe
CMD ["sh", "-c", "java -Dcantaloupe.config=/opt/cantaloupe/cantaloupe.properties -Dsoftware.amazon.awssdk.http.service.impl=software.amazon.awssdk.http.urlconnection.UrlConnectionSdkHttpService -jar /opt/cantaloupe/cantaloupe-$CANTALOUPE_VERSION.jar"]
