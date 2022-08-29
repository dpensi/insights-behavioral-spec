#!/bin/bash -ex

# Copyright 2022 Red Hat, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


dir_path=$(dirname $(realpath $0))
export PATH=$PATH:$dir_path
PATH_TO_LOCAL_NOTIFICATION_SERVICE="../ccx-notification-service"
PATH_TO_LOCAL_NOTIFICATION_WRITER="../ccx-notification-writer"

#set NOVENV is current environment is not a python virtual env
[ "$VIRTUAL_ENV" != "" ] || NOVENV=1

function install_reqs() {
	python3 $(which pip3) install -r requirements.txt
}

function prepare_venv() {
    echo "Preparing environment"
    # shellcheck disable=SC1091
    virtualenv -p python3 venv && source venv/bin/activate && python3 "$(which pip3)" install -r requirements/notification_service.txt
    echo "Environment ready"
}

function start_mocked_dependencies() {
    python3 $(which pip3) install -r requirements/mocks.txt
    pushd $dir_path/mocks/insights-content-service && uvicorn content_server:app --port 8082 &
    pushd $dir_path/mocks/prometheus && uvicorn push_gateway:app --port 9091 &
    pushd $dir_path/mocks/service-log && uvicorn service_log:app --port 8000 &
    trap 'kill $(lsof -ti:8082); kill $(lsof -ti:9091); kill $(lsof -ti:8000)' EXIT
    pushd $dir_path
    sleep 2  # wait for the mocks to be up
}

function get_binary() {
    (
        cd $PATH_TO_LOCAL_NOTIFICATION_SERVICE
        make build
    ) 
    cp "$PATH_TO_LOCAL_NOTIFICATION_SERVICE/ccx-notification-service" .
    # cp "$PATH_TO_LOCAL_NOTIFICATION_SERVICE/config.toml" .
    cp config/notification_service.toml config.toml
    trap 'rm ccx-notification-service; rm config.toml;' EXIT
}

function init_db() {
    (
        cd $PATH_TO_LOCAL_NOTIFICATION_WRITER
        make build
    ) 
    cp "$PATH_TO_LOCAL_NOTIFICATION_WRITER/ccx-notification-writer" .
    cp "$PATH_TO_LOCAL_NOTIFICATION_WRITER/config.toml" .
    ./ccx-notification-writer -db-init
    ./ccx-notification-writer -db-init-migration
    ./ccx-notification-writer -migrate latest
    rm ccx-notification-writer 
    rm config.toml
}

[ "$NOVENV" != "1" ] && install_reqs || prepare_venv || exit 1

#launch mocked services if WITHMOCK is provided
[ "$WITHMOCK" == "1" ] && start_mocked_dependencies

# Create all the tables
init_db

# Copy the binary and configuration to this folder
get_binary

# shellcheck disable=SC2068
PYTHONDONTWRITEBYTECODE=1 python3 "$(which behave)" \
    --format=progress2 \
    --tags=-skip --tags=-managed \
    -n "Check that notification service does not send messages to service log if it is disabled" \
    -D dump_errors=true @test_list/notification_service.txt "$@"
