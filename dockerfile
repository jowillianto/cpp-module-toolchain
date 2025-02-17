FROM ubuntu:jammy AS cmake
RUN echo "Acquire::http::Pipeline-Depth 0; \n Acquire::http::No-Cache true; \n Acquire::BrokenProxy true;" > /etc/apt/apt.conf.d/99fixbadproxy
RUN apt clean
RUN rm -rf /var/lib/apt/lists/*

# Get add-apt-repository
RUN apt update && apt install -y software-properties-common

# Add CMAKE Dependencies
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | \
  gpg --dearmor - | \
  tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null
RUN apt-add-repository "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main"
RUN rm /etc/apt/trusted.gpg.d/kitware.gpg
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 16FAAD7AF99A65E2
RUN apt update && apt install -y cmake=3.31.5-0kitware1ubuntu22.04.1

# Install Ninja
FROM ubuntu:jammy AS ninja
RUN apt update && apt install -y \
  curl \
  cmake \
  g++
WORKDIR /opt
RUN curl -sfSL https://github.com/ninja-build/ninja/archive/refs/tags/v1.12.1.tar.gz -o /opt/ninja.tar.gz
RUN tar -xzf /opt/ninja.tar.gz
WORKDIR /opt/ninja-1.12.1
RUN cmake -Bbuild .
WORKDIR /opt/ninja-1.12.1/build
RUN make
RUN cp ninja /usr/bin/ninja

FROM ubuntu:jammy AS llvm
ARG LLVM_VERSION="17"
# Install LLVM
RUN apt update -o Acquire::CompressionTypes::Order::=gz && apt install -y \
  curl \
  lsb-release \
  wget \
  software-properties-common \
  gnupg \
  cmake
WORKDIR /opt
RUN curl https://apt.llvm.org/llvm.sh -o /opt/llvm.sh
RUN chmod +x llvm.sh
RUN ./llvm.sh ${LLVM_VERSION} all
RUN ln -s /usr/lib/llvm-${LLVM_VERSION}/bin/clang-scan-deps /usr/bin/clang-scan-deps
RUN ln -s /usr/bin/clang++-${LLVM_VERSION} /usr/bin/clang++
RUN ln -s /usr/bin/clang-${LLVM_VERSION} /usr/bin/clang

FROM llvm AS final
# COPY CMake
COPY --from=cmake /usr/bin/cmake /usr/bin/cmake
COPY --from=cmake /usr/share/cmake-3.31 /usr/share/cmake-3.31
# COPY Ninja
COPY --from=ninja /usr/bin/ninja /usr/bin/ninja