#!/bin/bash          
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/includes.sh"

# This script will pull the newest version of Push from the git repository.
# If Push wasn't set up with git this will break pretty fantastically.

# Borrowed from https://stackoverflow.com/a/21128172
rebuild='false'

while getopts 'r' flag; do
  case "${flag}" in
    r) rebuild='true' ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done

check_if_docker_is_running

# Pull the Git repository
echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE
echoc "Updating the Push software from the git repository" $GREEN
echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE

# error=$(git pull origin master --rebase | tee /dev/tty | grep 'error')

# if ! [[ -z "${error// }" ]]; then

if ! [ "$(git pull origin master --rebase)" ]; then
  echoc "\n-------------------------------------------------------------------------------------------------------------" $RED
  echoc "There was an error in upgrading from Git.\n" $RED
  echoc "Please review the console output and submit a bug report if you think it's necessary."
  echoc "\n-------------------------------------------------------------------------------------------------------------" $RED
  exit 100
else
  echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE
  echoc "Successfully pulled new code!" $LIGHT_BLUE
  echoc "\n-------------------------------------------------------------------------------------------------------------\n\n" $LIGHT_BLUE
fi

# Stop the cert docker-compose containers
kill_docker_containers

if ! [ "$rebuild" = true ]; then 
  echoc "Rebuilding Containers\n" $LIGHT_BLUE
  echoc "---------------------------------------------------------------------------------------------------------------\n"
  $(docker-compose -f docker-compose.yml build)
fi

if basename "$PWD" | grep 'maintence-scripts' > /dev/null; then
  command='docker-compose -f ../docker-compose.yml up -d'
else
  command='docker-compose -f docker-compose.yml up -d'
fi

error=$($command | tee /dev/tty | grep 'The following errors were reported by the server')

if ! [[ -z "${error// }" ]]; then
  echoc "\n-------------------------------------------------------------------------------------------------------------" $RED
  echoc "There was an error in restarting your production containers.\n" $RED
  echoc "Please review the console output and submit a bug report if you think it's necessary."
  echoc "\n-------------------------------------------------------------------------------------------------------------" $RED
  exit 100
else
  echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE
  echoc "Successfully booted up the production servers!" $LIGHT_BLUE
  echoc "\n-------------------------------------------------------------------------------------------------------------\n\n" $LIGHT_BLUE
fi
