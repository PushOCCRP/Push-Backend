#!/bin/bash          
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/includes.sh"

# This script is for exporting various parts of the app

function import_full_db {
  echoc "Exporting full database..." $GREEN
  name="push_production_$(timestamp).sql"
  $(docker-compose exec --user postgres db psql production < $1)

  error=$(grep 'failed' $name)
  if ! [[ -z "${error// }" ]]; then
    echoc "\n-------------------------------------------------------------" $RED
    echoc "There was an error in your export:\n" $RED
    cat $name
    echoc "\n-------------------------------------------------------------" $RED
    echoc "Please review the console output and submit a bug report if you think it's necessary."
    echoc "-------------------------------------------------------------" $RED
    rm $name
    exit 100
  else
    echoc "\n-------------------------------------------------------------"n" $LIGHT_BLUE
    echoc "Successfully generated your SSL keys!" $LIGHT_BLUE
    echoc "\n-------------------------------------------------------------"n\n" $LIGHT_BLUE
  fi

}

echoc "\nPush Project Backend Import Utility\n"

import_full_db $1

echoc "Import completed"

# echoc "Setting up a $cms installation" $GREEN

# if [[ -z "${error// }" ]]; then
#   echoc "\n-------------------------------------------------------------------------------------------------------------" $RED
#   echoc "There was an error in generating your certificates.\n" $RED
#   echoc "Please review the console output and submit a bug report if you think it's necessary."
#   echoc "\n-------------------------------------------------------------------------------------------------------------" $RED
#   exit 100
# else
#   echoc "\n-------------------------------------------------------------------------------------------------------------\n" $LIGHT_BLUE
#   echoc "Successfully generated your SSL keys!" $LIGHT_BLUE
#   echoc "\n-------------------------------------------------------------------------------------------------------------\n\n" $LIGHT_BLUE
# fi