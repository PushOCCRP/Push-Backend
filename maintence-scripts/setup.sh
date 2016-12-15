#!/bin/bash

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/includes.sh"

function kill_docker_containers {
  echo -e "\n\e[94mStopping any errantly running docker containers\e[0m"
  echo -e "\e[94m---------------------------------\e[0m\n"
  docker stop $(docker ps -a -q)
  docker rm $(docker ps -a -q)
}

echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE
echoc "Setting up a new Push server..." $LIGHT_BLUE
echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE

if basename "$PWD" | grep 'maintence-scripts' > /dev/null; then
  path='./setup-cms_env.sh'
else
  path='./maintence-scripts/setup-cms_env.sh'
fi

bash $path

echoc '\n---------------------------------------------------------\n' $LIGHT_BLUE
echoc '    Moving on to generating SSL keys \n' $LIGHT_BLUE
echoc '---------------------------------------------------------\n\n' $LIGHT_BLUE 

if basename "$PWD" | grep 'maintence-scripts' > /dev/null; then
  path='./setup-lets_encrypt.sh'
else
  path='./maintence-scripts/setup-lets_encrypt.sh'
fi

exit_code=$(bash $path)

if [ "$exit_code" = 0]; then
  echoc '\n---------------------------------------------------------\n' $LIGHT_BLUE
  echoc "    Theoretically you\'re done!!! \n" $LIGHT_BLUE
  echoc '---------------------------------------------------------\n\n' $LIGHT_BLUE
else
  echoc '---------------------------------------------------------\n\n' $RED
  echoc "It looks like there were some errors. I'm sorry about that, I know it can be frustrating"
  echoc "Please review any messages and post bug reports if you believe it's an inapproriate error."
fi