#!/bin/bash

# Author: Aleksandar Todorović
# Contact: aleksandar@r3bl.me

# ----------------------------------------------------------------------------------
# -- A script to spin up Push servers on a local server (without relying on AWS), --
# -- in a multiple instance server setup.                                         --
# ----------------------------------------------------------------------------------

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/includes.sh"

echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE
echoc "Setting up a new Push server..." $LIGHT_BLUE
echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE

if basename "$PWD" | grep 'maintence-scripts' > /dev/null; then
  path='./cms_cleaner.sh'
else
  path='./maintence-scripts/cms_cleaner.sh'
fi

if basename "$PWD" | grep 'maintence-scripts' > /dev/null; then
  cp docker-compose-files/docker-compose-no-nginx.yml ../docker-compose.yml
else
  cp maintence-scripts/docker-compose-files/docker-compose-no-nginx.yml docker-compose.yml
fi

bash $path

if [ "$?" = 0 ]; then
  echoc '\n---------------------------------------------------------\n' $LIGHT_BLUE
  echoc "    Theoretically you\'re done!!!\n" $LIGHT_BLUE
  if basename "$PWD" | grep 'maintence-scripts' > /dev/null; then
    echoc "Run \"docker-compose -f ../docker-compose.yml up\" to make sure everything's fine. \n" $LIGHT_BLUE
  else
    echoc "Run \"docker-compose up\" to make sure everything's fine. \n" $LIGHT_BLUE
  fi
  echoc '\n---------------------------------------------------------\n' $LIGHT_BLUE
else
  echoc '\n---------------------------------------------------------' $RED
  echoc "It looks like there were some errors. I'm sorry about that, I know it can be frustrating"
  echoc "Please review any messages and post bug reports if you believe it's an inapproriate error."
  echoc '---------------------------------------------------------' $RED
fi
