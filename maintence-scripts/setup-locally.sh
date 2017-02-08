#!/bin/bash

# A script to spin up Push servers on a local server (without relying on AWS), in a multiple instance
# server setup.
# Author: Aleksandar Todorović
# Date: January 25th, 2017
# Contact: aleksandar@r3bl.me

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/includes.sh"

# This would break a lot of things in the multi-website hosting scenario

#function kill_docker_containers {
#  echo -e "\n\e[94mStopping any errantly running docker containers\e[0m"
#  echo -e "\e[94m---------------------------------\e[0m\n"
#  docker stop $(docker ps -a -q)
#  docker rm $(docker ps -a -q)
#}

echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE
echoc "Setting up a new Push server..." $LIGHT_BLUE
echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE

if basename "$PWD" | grep 'maintence-scripts' > /dev/null; then
  path='./cms_cleaner.sh'
else
  path='./maintence-scripts/cms_cleaner.sh'
fi

bash $path

if [ "$?" = 0 ]; then
  echoc '\n---------------------------------------------------------\n' $LIGHT_BLUE
  echoc "    Theoretically you\'re done!!!\n" $LIGHT_BLUE
  echoc "Run \"docker-compose -f ../docker-compose-no-nginx.yml up\" to make sure everything's fine. \n" $LIGHT_BLUE
  echoc '\n---------------------------------------------------------\n' $LIGHT_BLUE
else
  echoc '\n---------------------------------------------------------' $RED
  echoc "It looks like there were some errors. I'm sorry about that, I know it can be frustrating"
  echoc "Please review any messages and post bug reports if you believe it's an inapproriate error."
  echoc '---------------------------------------------------------' $RED
fi
