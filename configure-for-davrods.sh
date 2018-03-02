#!/usr/bin/env bash

SUMMATESTCASES_DIR=$(pwd)/summaTestCases_2.x
SUMMA_REPOSITORY=bartnijssen/summa
SUMMA_TAG=latest

_get_machine() {
  local unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)     machine=Linux;;
      Darwin*)    machine=macOS;;
      CYGWIN*)    machine=Cygwin;;
      MINGW*)     machine=MinGw;;
      *)          machine="UNKNOWN:${unameOut}"
  esac
  if [[ "$machine" != "macOS" ]] && [[ "$machine" != "Linux" ]]; then
    echo "WARNING: ${machine} platform is unsupported at this time... exiting"
    exit 1;
  else
    echo "INFO: configuring for ${machine}"
  fi
}

### NOT USED - due to failed build ###
# clone summa repo if needed and build from develop branch
_check_summa_image() {
  if [[ "$(docker images | grep summa | tr -s ' ' | cut -d ' ' -f 2)" == "$SUMMA_TAG" ]]; then
    echo "INFO: image ${SUMMA_REPOSITORY}:${SUMMA_TAG} already exists"
  else
    echo "INFO: building image ${SUMMA_REPOSITORY}:${SUMMA_TAG}"
    git clone https://github.com/NCAR/summa.git
    cd summa
    git checkout develop
    cat > Dockerfile << EOF
# use the zesty distribution, which has gcc-6
FROM ubuntu:bionic

# install only the packages that are needed
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    make \
    gfortran-6 \
    libnetcdff-dev \
    liblapack-dev \
    && apt-get clean

# set environment variables for docker build
ENV F_MASTER /code
ENV FC gfortran
ENV FC_EXE gfortran
ENV FC_ENV gfortran-6-docker

WORKDIR /usr/bin
RUN ln -s x86_64-linux-gnu-gfortran-6 gfortran

# add code directory
WORKDIR /code
COPY . /code

# fetch tags and build summa
RUN git fetch --tags && make -C build/ -f Makefile

# run summa when running the docker image
WORKDIR /code/bin
ENTRYPOINT ["./summa.exe"]
EOF
    docker build -t ${SUMMA_REPOSITORY}:${SUMMA_TAG} .
    cd -
  fi
}

# untar the test cases, remove prior untarred file if they exist
_untar_testcases() {
  if [[ -d summaTestCases_2.x ]]; then
    rm -rf summaTestCases_2.x
  fi
  tar -xzf summatestcases-2.x.tar.gz
}

# update installTestCases_docker_davrods.sh
_installTestCases_docker_sh() {
  INSTALLTESTCASES_DOCKER_FILE=${SUMMATESTCASES_DIR}/installTestCases_docker.sh
  INSTALLTESTCASES_DOCKER_FILE_DAVRODS=${SUMMATESTCASES_DIR}/installTestCases_docker_davrods.sh
  cp $INSTALLTESTCASES_DOCKER_FILE $INSTALLTESTCASES_DOCKER_FILE_DAVRODS
  if [[ "$machine" == "macOS" ]]; then
    sed -i "" \
      -e "s/mkdir -p/docker exec -u irods irods-provider imkdir -p/g" \
      -e "s/BASEDIR=.*/BASEDIR=\//" \
      $INSTALLTESTCASES_DOCKER_FILE_DAVRODS
  elif [[ "$machine" == "Linux" ]]; then
    sed -i \
      "s/mkdir -p/docker exec -u irods irods-provider imkdir -p/g;
      s/BASEDIR=.*/BASEDIR=\//" \
      $INSTALLTESTCASES_DOCKER_FILE_DAVRODS
  fi
}

# update runTestCases_docker_davrods.sh
_runTestCases_docker_sh() {
  RUNTESTCASES_DOCKER_FILE=${SUMMATESTCASES_DIR}/runTestCases_docker.sh
  RUNTESTCASES_DOCKER_FILE_DAVRODS=${SUMMATESTCASES_DIR}/runTestCases_docker_davrods.sh
  cp $RUNTESTCASES_DOCKER_FILE $RUNTESTCASES_DOCKER_FILE_DAVRODS
  if [[ "$machine" == "macOS" ]]; then
    sed -i "" \
      -e "s~DOCKER_TEST_CASES_PATH=.*~DOCKER_TEST_CASES_PATH="$(pwd)"~" \
      -e "s~SUMMA_EXE=bartnijssen/summa:latest~SUMMA_EXE=$SUMMA_REPOSITORY:$SUMMA_TAG~" \
      -e "s~DISK_MAPPING=.*~DISK_MAPPING='--mount source=davrods-volume,target=/summaTestCases_2.x'~" \
      -e "s/docker run -v/sleep 5s; docker run --rm/g" \
    $RUNTESTCASES_DOCKER_FILE_DAVRODS
  elif [[ "$machine" == "Linux" ]]; then
    sed -i \
      "s~DOCKER_TEST_CASES_PATH=.*~DOCKER_TEST_CASES_PATH="$(pwd)"~;
      s~SUMMA_EXE=bartnijssen/summa:latest~SUMMA_EXE=$SUMMA_REPOSITORY:$SUMMA_TAG~;
      s~DISK_MAPPING=.*~DISK_MAPPING='--mount source=davrods-volume,target=/summaTestCases_2.x'~;
      s/docker run -v/sleep 5s; docker run --rm/g" \
      $RUNTESTCASES_DOCKER_FILE_DAVRODS
  fi
}

# clean up docker environment
_clean_slate() {
  docker stop \
    irods-provider \
    davrods-server
  docker rm -fv \
    irods-provider \
    davrods-server
  docker network rm \
    summa-davrods
  docker volume rm \
    davrods-volume
}

# instantiate the iRODS server
_irods_server() {
  if [[ -d $(pwd)/irods ]]; then
    sudo rm -rf $(pwd)/irods
    mkdir -p $(pwd)/irods/var_irods
    mkdir -p $(pwd)/irods/etc_irods
    mkdir -p $(pwd)/irods/var_pgdata
  fi
  docker run -d --name irods-provider \
  	-h irods-provider \
    --net=summa-davrods \
  	-v $(pwd)/irods/var_irods:/var/lib/irods \
  	-v $(pwd)/irods/etc_irods:/etc/irods \
  	-v $(pwd)/irods/var_pgdata:/var/lib/postgresql/data \
    -e UID_IRODS=${UID} \
  	mjstealey/irods-provider-postgres:4.2.2 \
  	-i run_irods
  echo "Allowing irods-provider to setup..."
  ZONE=$(echo $(docker exec -ti -u irods irods-provider iadmin lz) | tr -d '\r')
  until [ "$ZONE" == "tempZone" ]; do
    echo "...waiting"
    sleep 3s
    ZONE=$(echo $(docker exec -ti -u irods irods-provider iadmin lz) | tr -d '\r')
  done
  echo "INFO: irods-provider is running"
}

# populate iRODS server with sample data
_populate_irods() {
  docker run --rm \
    -e IRODS_HOST=irods-provider \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone \
    -e IRODS_PASSWORD=rods \
    -e UID_IRODS=${UID} \
    --net=summa-davrods \
    -v $(pwd)/summaTestCases_2.x:/summaTestCases_2.x \
    mjstealey/irods-icommands:4.2.2 \
    iput -r /summaTestCases_2.x/settings
  docker run --rm \
    -e IRODS_HOST=irods-provider \
    -e IRODS_USER_NAME=rods \
    -e IRODS_ZONE_NAME=tempZone \
    -e IRODS_PASSWORD=rods \
    -e UID_IRODS=${UID} \
    --net=summa-davrods \
    -v $(pwd)/summaTestCases_2.x:/summaTestCases_2.x \
    mjstealey/irods-icommands:4.2.2 \
    iput -r /summaTestCases_2.x/testCases_data
  docker exec -u irods irods-provider ils
}

# instantiate the DavRODS server
_davrods_server() {
  docker run -d --name davrods-server \
   	-e IRODS_CLIENT_SERVER_POLICY=CS_NEG_REFUSE \
   	-e IRODS_SERVER_CONTROL_PLANE_KEY=TEMPORARY__32byte_ctrl_plane_key \
   	-e VHOST_SERVER_NAME=localhost \
   	-e VHOST_DAV_RODS_SERVER='irods-provider 1247' \
   	-e VHOST_DAV_RODS_ZONE=tempZone \
   	-p 8080:80 \
    -h davrods-server \
    --net=summa-davrods \
   	renci/docker-davrods:4.2.1
  echo "Allowing davrods-server to setup..."
  DAVRODS=$(echo $(curl -sSL -D - localhost:8080 -o /dev/null | grep 'HTTP/1.1 401 Unauthorized') | tr -d '\r')
  until [ "$DAVRODS" == "HTTP/1.1 401 Unauthorized" ]; do
    echo "...waiting"
    sleep 3s
    DAVRODS=$(echo $(curl -sSL -D - localhost:8080 -o /dev/null | grep 'HTTP/1.1 401 Unauthorized') | tr -d '\r')
  done
  echo "INFO: davrods-server avaialble at: http://localhost:8080/"
  echo "  - user: rods"
  echo "  - pass: rods"
}

# create a WebDAV enabled volume to connect to DavRODS
_davrods_volume() {
  docker volume create \
    -d fentas/davfs \
    -o url=http://rods:rods@localhost:8080 \
    -o uid=1000 \
    -o gid=1000 \
    davrods-volume
}

#### main ####

# get machine type
_get_machine

# check for ${SUMMA_REPOSITORY}:${SUMMA_TAG} image
# _check_summa_image

# gracefully stop and remove any prior containers
_clean_slate

# prep run scripts for use by DavRODS
_untar_testcases
_installTestCases_docker_sh
_runTestCases_docker_sh

# create docker network
docker network create summa-davrods

# stand up iRODS container and populate with test case data
_irods_server
cd summaTestCases_2.x
./installTestCases_docker_davrods.sh
cd -
_populate_irods

# stand up DavRODS server and connect to iRODS as rods user
_davrods_server
_davrods_volume

# user instructions
echo "INFO: Ready to run test cases in Docker:"
echo "  - $ cd summaTestCases_2.x"
echo "  - $ ./runTestCases_docker_davrods.sh"

exit 0;
