#!/bin/bash          
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/includes.sh"

# This script will renew the let's encrypt ssl certs, if needed

if basename "$PWD" | grep 'maintence-scripts' > /dev/null; then
  path='../.env'
else
  path='./.env'
fi

if [ ! -f $path ]; then
  echoc "No .env file found, please run the 'setup-lets_encrypt.sh' script first." $YELLOW
  exit
fi

# Stop the production docker-compose containers
kill_docker_containers

# Renew the ssl certs
echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE
echoc "Renewing SSL certificates" $GREEN
echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE

if basename "$PWD" | grep 'maintence-scripts' > /dev/null; then
  command='docker-compose -f ../letsencrypt-docker-compose.yml up'
else
  command='docker-compose -f letsencrypt-docker-compose.yml up'
fi

error=$($command | tee /dev/tty | grep 'The following errors were reported by the server')


if ! [[ -z "${error// }" ]]; then
  echoc "\n-------------------------------------------------------------------------------------------------------------" $RED
  echoc "There was an error in renewing your certificates.\n" $RED
  echoc "Please review the console output and submit a bug report if you think it's necessary."
  echoc "\n-------------------------------------------------------------------------------------------------------------" $RED
  exit 100
else
  echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE
  echoc "Successfully renewed your SSL keys!" $LIGHT_BLUE
  echoc "\n-------------------------------------------------------------------------------------------------------------\n\n" $LIGHT_BLUE
fi

# Stop the cert docker-compose containers
kill_docker_containers

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