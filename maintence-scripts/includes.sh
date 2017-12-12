#!/bin/bash

# Common includes for bash scripts
# Author: Christopher Guess
# Date: December 15, 2016
# Contact: cguess@gmail.com

# To use this in your script add the following lines to the top of the script (uncommented)
#
# DIR="${BASH_SOURCE%/*}"
# if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
# . "$DIR/includes.sh"
#



# A list of color constants that can be used
# NOTE: Most of these are very wrong
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT_GRAY='\033[0;37m'
DARK_GRAY='\033[0;38m'
LIGHT_RED='\033[0;39m'
LIGHT_GREEN='\033[1;30m'
YELLOW='\033[1;31m'
LIGHT_BLUE='\033[1;32m'
LIGHT_PURPLE='\033[1;33m'
LIGHT_CYAN='\033[1;34m'
WHITE='\033[1;35m'
NC='\033[0m'

# echos a string with a given color constant
# ex: echoc "Hello World!" $RED
function echoc {
  printf "$2$1${NC}\n"
}

function timestamp {
  date +"%Y%m%d-%H:%M:%S"
}

# asks a yes or no question, echos 'true' for yes, 'false' for no
# ex: answer=$(askyn 'Are you a god?')
# ex: askyn 'Are you a god?' $answer
function askyn {
  local  __resultvar=$2
  while true
  do
    read -p "$1 [y/n] " choice
    if [[ $choice =~ ^(yes|y|YES|Y|N|NO|no|n| ) ]]; then
      break
    fi
  done
  
  case "$choice" in 
    y|Y|yes|YES ) 
      answer=true;
      ;;
    n|N|no|NO ) 
      answer=false;
      ;;
    * ) echo "Please answer y or n";;
  esac

  if [[ "$__resultvar" ]]; then
    eval $__resultvar=$answer
  else
    echo $answer
  fi
}

# Borrow from https://stackoverflow.com/questions/1527049/bash-join-elements-of-an-array
# Joins an array by a delimiter
# ex: join_by , a "b c" d #a,b c,d
#     join_by / var local tmp #var/local/tmp
#     join_by , "${FOO[@]}" #a,b,c
function join_by { local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}"; }

# This is the setup script for Lets Encrypt on a new Push Backend Server.

function kill_docker_containers {
  echoc "\n-------------------------------------------------------------------------------------------------------------\n" $BLUE
  echoc "Stopping any errantly running docker containers" $BLUE
  echoc "\n-------------------------------------------------------------------------------------------------------------\n" $BLUE
  if [ -n "$(docker ps -a -q)" ]; then
    docker stop $(docker ps -a -q)
    docker rm $(docker ps -a -q)
  fi
}

function check_if_docker_is_running {
  if [ ! "$(docker ps)" ]; then
    echoc "\n-------------------------------------------------------------------------------------------------------------" $RED
    echoc "ERROR: The Docker engine doesn't seem to be running.\n" $RED
    echoc "Please review the console output and submit a bug report if you think it's necessary."
    echoc "\n-------------------------------------------------------------------------------------------------------------" $RED
    exit 100
  fi
}
