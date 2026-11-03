# Build and runtime image of the standalone RePlAce for run_replace_gp.sh (REPLACE_IMAGE,
# default replace-build:u18). Its own Dockerfile (CentOS 6) no longer builds.
#   docker build -t replace-build:u18 -f replace.Dockerfile .
#   git clone --recursive --branch standalone https://github.com/The-OpenROAD-Project/RePlAce.git ~/RePlAce
#   git -C ~/RePlAce apply $PWD/replace_dummy_terms.patch     (7c07cff; the dummy terminals of the row-free core)
#   docker run --rm -u $(id -u):$(id -g) -v ~/RePlAce:/RePlAce -w /RePlAce replace-build:u18 \
#     bash -c 'mkdir -p build && cd build && cmake .. && make -j16'
FROM ubuntu:18.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y build-essential cmake git libx11-dev libboost-all-dev swig flex bison \
    libtool zlib1g-dev tcl-dev tk-dev libjpeg-dev libgomp1 && rm -rf /var/lib/apt/lists/*
