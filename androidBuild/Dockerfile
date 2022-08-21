FROM ubuntu:20.04

ENV TZ=Europe/London
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    bash \
    cmake \
    build-essential \
    git \
    python3 \
    rapidjson-dev \
    libsdl2-dev \
    wget \
    strace \
    patchelf \
    unzip

RUN mkdir -p /avbuild
WORKDIR /avbuild

RUN wget -O /avbuild/ndk.zip https://dl.google.com/android/repository/android-ndk-r25-linux.zip
RUN chmod +x /avbuild/ndk.zip
RUN unzip /avbuild/ndk.zip
RUN rm /avbuild/ndk.zip

RUN wget -O /avbuild/sdk.zip https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip
RUN chmod +x /avbuild/sdk.zip
RUN unzip /avbuild/sdk.zip
RUN rm /avbuild/sdk.zip




# # Install basic software support
RUN apt-get update && \
    apt-get install --yes software-properties-common


RUN add-apt-repository ppa:openjdk-r/ppa
RUN apt-get update
RUN apt-get --yes --no-install-recommends install openjdk-8-jdk


# # Install basic software support
# RUN apt-get update && \
#     apt-get install --yes software-properties-common

# # Add the JDK 8 and accept licenses (mandatory)
# RUN add-apt-repository ppa:webupd8team/java && \
#     echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
#     echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections

# # Install Java 8
# RUN apt-get update && \
#     apt-get --yes --no-install-recommends install oracle-java8-installer



RUN mkdir /avbuild/sdk
#Just to see what options there are.
RUN /avbuild/cmdline-tools/bin/sdkmanager --list --sdk_root=/avbuild/sdk
RUN yes | /avbuild/cmdline-tools/bin/sdkmanager --sdk_root=/avbuild/sdk "platforms;android-24" "ndk-bundle" "ndk;25.0.8775105" "build-tools;33.0.0" "build-tools;24.0.3" "cmake;3.22.1"

COPY build.sh /avbuild/build.sh
COPY ogreFix.diff /avbuild/ogreFix.diff

RUN useradd -ms /bin/bash builder
#USER builder

#ENTRYPOINT ["/avbuild/scripts/entrypoint.sh"]
