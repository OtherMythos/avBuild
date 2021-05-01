FROM ubuntu:20.04

ENV TZ=Europe/London
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    bash \
    cmake \
    build-essential \
    git \
    python3 \
    libxaw7-dev \
    libxrandr-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    rapidjson-dev \
    libsdl2-dev

RUN mkdir -p /avbuild/build
WORKDIR /avbuild/build
COPY entrypoint.sh /avbuild/scripts/entrypoint.sh
RUN chmod +x /avbuild/scripts/entrypoint.sh

#Resolves a problem with root permissions when building ogre deps.
#RUN mkdir -p /usr/local/lib/pkgconfig
RUN chmod 777 /usr/local/lib/
RUN chmod 777 /usr/local/include
RUN chmod 777 /usr/local/bin

RUN useradd -ms /bin/bash builder
USER builder

#ENTRYPOINT ["/avbuild/scripts/entrypoint.sh"]
