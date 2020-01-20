#!/bin/bash
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/includes.sh"

# Stop any possible docker-compose containers that might be sticking around
kill_docker_containers

# Migrate the database (does nothing if database already exists)
echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE
echoc "Migrating the Push app database" $LIGHT_BLUE
echoc "\n-------------------------------------------------------------------------------------------------------------\n\n" $LIGHT_BLUE

docker-compose run web rake db:create
docker-compose run web rake db:migrate
docker-compose run web rake db:seed

echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE
echoc "Everything should be set up properly now."
echoc "Try running"
echoc "docker-compose up" $YELLOW
echoc "to make sure it works"
echoc "\n-------------------------------------------------------------------------------------------------------------\n\n" $LIGHT_BLUE
