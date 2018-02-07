#!/bin/bash          
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/includes.sh"

# This script is for exporting various parts of the app

function export_full_db {
  echoc "Exporting full database..." $GREEN
  name="push_production_$(timestamp).sql"
  $(docker-compose exec --user postgres db pg_dump -Fc production > $name)

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

function export_analytics {
  echoc "Exporting backend analytics..." $GREEN
  command="..."
  export_from_db   
}

function export_notifications {
  echoc "Exporting push notifications history..." $GREEN
  command="..."
  export_from_db   
}

function export_devices {
  echoc "Exporting user devices..." $GREEN
  export_from_db '', 
}

echoc "\nPush Project Backend Export Utility\n"

# When I figure out how to do commands we'll skip this if something's put in.
# bash options list?
PS3='Please choose what you would like to export: '
options=("Full Database" "Analytics" "Push Notifications" "Devices")
select opt in "${options[@]}"
do
    case $opt in
        "Full Database")
            export_type='full'
            export_full_db
            break
            ;;
        "Analytics")
            export_type='analytics';
            break
            ;;
        "Push Notifications")
            export_type='notifications';
            break
            ;;
        "Devices")
            export_type='devices';
            break
            ;;
        *) echo invalid option;;
    esac
done

echoc "Export completed"

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