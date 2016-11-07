#!/bin/bash          

function kill_docker_containers {
  echo -e "\n\e[94mStopping any errantly running docker containers\e[0m"
  echo -e "\e[94m---------------------------------\e[0m\n"
  docker stop $(docker ps -a -q)
  docker rm $(docker ps -a -q)
}

echo "Setting up a new Push server..."
 
# Ask the email of the main user

while true
do
  echo -en "What is your email address? "
  read email
  if ! echo "$email" | grep -qiP "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$" ;then
    echo -e "\e[91mNot a valid email address. Please try again.\e[0m"
  else
    break
  fi
done
 
# Ask the name of the site

while true
do
  echo -en "What is the host name for this installation (e.g. testapp.pushapp.press)? "
  read host
  if ! echo "$host" | grep -qiP "^[A-z]*[\.]*[A-z]+[\.][A-z]+$" ;then
    echo -e "\e[91mNot a valid URL format. Please try again.\e[0m"
  else
    break
  fi
done

# Write the .env file for the LetsEncrypt variables
# This overwrites the current file

# If there's no .env, create it.
if [ ! -f ./.env ]; then
    echo "No .env file found, creating it."
else
  echo "Removing current .env file"
  rm ./.env
fi

touch ./.env

# Write the .env file
echo -e "\e[94mCreating .env file for $email and $host\e[0m"
cat <<EOT >> .env
###########################################################################################
# Environmental variables for LetsEncrypt and Push
#
# This file is automatically generated and is overwritten by maintence-scripts/setup.sh
# Since that script will only usually be automatically written to once feel free to edit.
###########################################################################################

LETSENCRYPT_EMAIL=$email
LETSENCRYPT_DOMAINS=$host
LETSENCRYPT_STAGING=
RAILS_ENV=production
EOT

# Stop any possible docker-compose containers that might be sticking around
kill_docker_containers

# Create the proper ssl certs
echo -e "\n\e[94mCreating SSL certificates\e[0m"
echo -e "\e[94m---------------------------------\e[0m\n"
docker-compose -f letsencrypt-docker-compose.yml up

# Stop any possible docker-compose containers that might be sticking around
kill_docker_containers

# Migrate the database (does nothing if database already exists)
echo -e "\n\e[94mMigrating the Push app database\e[0m"
echo -e "\e[94m---------------------------------\e[0m\n"
docker-compose run web rake db:create
docker-compose run web rake db:migrate
docker-compose run web rake db:seed

# Generate the dhparam file, this happens when we bring up the nginx container
docker-compose run -e NGINX_BOOT=false nginx

echo -e "Everything should be set up properly now."
echo -e "Try running \e[96mdocker-compose up\e[0m to make sure it works"