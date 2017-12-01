# Push-Backend
## Introduction
This operates as a middleman between the plugin installed on the CMS and the apps. It provides a consistant API for the mobile apps to connect to while also sanitizing, caching, routing and doing general best practices on the HTML coming out of the CMS.

This app is set up to run on Docker, which handles 90% of the set up for the database and such. The main thing a user has to worry about is setting up the APNS (Apple Push Notification Service) and Firebase certs.

## Overview
This consists of five systems.
- Web
-- This is the main Ruby on Rails 4.2.2 app. It's an utterly standard Rails app which uses Puma as the front server for multithreading and such.
- Nginx
-- Set up to be a basic proxy server to insure SSL connectivity and passthrough to the Puma server running the Rails app.
- Postgres
-- The database that the app uses. Utterly vanilla installation.
- Uniqush 
-- A really great open source push notification server that handles all the certificates, devices settings and actual pushing of notifications.
- Redis
-- Used by Uniqush to save data.

- secrets.env
-- This file contains all the data to customize the server. The code is commented appropriately.

# Setup
Theres a few different ways to set this up (and if you're familiar with Docker probably a bunch more). However, this will be the best way to get going from scratch. 


## Setup From Scratch 
#### (Skip to next section if you're using the AWS setup [scripts}(https://github.com/PushOCCRP/Push-AWS-Launcher)

#### Some Notes
- This will assume you're setting up on a Debian-based Linux system (Debian/Ubuntu etc.)
- The steps should be similar for Red Hat etc, but with some small differences in the package manager etc.
- Please use Ubuntu 14.04 or greater. This has been tested with versions up to Ubuntu Zesty 17.01
- You must have ```sudo``` permission on the server, if you don't contact your administrator.
- All of this is run from within an SSH terminal session, none of this is done locally on your machine, unless you're explicitly meaning to run it off your machine, which I don't recommend.
- For development purposes there is a Vagrant box setup file provided. However, getting the SSL keys to run properly is currently a challenge. If you have ideas please send them over.
- The faster the machine you're running it on the faster the set up goes. However, the actual backend software runs pretty well on an AWS-Micro instance for testing and an AWS-Small instance in production.
- I'd recommend installing [Mosh](https://mosh.org/), (it's already on the AWS instance). This lets you close the session while waiting and resume later. Very helpful on trains, VPNs, airplanes and over sketchy connections in developing world countries.


1. Update your repositories ```sudo apt-get update```
1. Install Docker with instructions [here](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-docker-ce) (hint: you're probably using ```amd64``` unless you definitely know you're not)
1. Install Docker Compose [here](https://docs.docker.com/compose/install/) (make sure you click the ```Linux``` tab for the instructions)
1. Add your user to the docker group ```sudo usermod -aG docker ${USER}```
1. Log out and log back into the machine to reset the permissions.
1. Install Git ```sudo apt-get install git```
1. Pull code from the Push Backend repository ```git clone https://github.com/PushOCCRP/Push-Backend.git```

#### Start here if using the AWS setup script.
1. ```cd Push-Backend```
1. Run the set up scripts ```bash ./maintence-scripts/setup.sh```
1. From here there will be a bunch of questions to answer, it should be quite self explanatory
1. After answering some questions it will also set up your SSL keys, so everything is secure. The questions may repeat a bit.
1. Be patient, there's a bunch of stuff going on here including building a bunch of different Docker containers, and creating SSL keys, which can take A LONG time. It really depends on the machine. If you're on an AWS micro instance go for a run, take a shower, whatever, you have at least 45 minutes, maybe two hours to kill.
1. After waiting far too long, run ```docker-compose up``` and everything should build and boot automatically. If there are any errors you should see them in the log
1. If all is good ctrl-c to close down. Then run ```docker-compose up -d``` to start in the background
1. At this point you're good to go. You can exit your server and rest easy.


# Running
After following the steps above, ```docker-compose up -d``` should be all you need to run the project.

# Troubleshooting

- If you get an error like ```ERROR: Couldn't connect to Docker daemon at http+docker://localunixsocket - is it running?``` check that your user is in the ```docker``` group. To do that run ```groups $USER``` If it is, log out and logging back in should fix the problem.

- If you're having troubles connecting from your browser, make sure that you have port 443 open to incoming traffic on the server.

# Setting Up Push Notifiations

TBD, this is annoyingly complicated.

# Notes

### DNS HOST
A DNS host entry is what tells the internet that your URL (e.g. https://www.example.com) points to your server's IP (e.g. 192.168.1.1). Depending on your hosting company this is can be set automatically or sometimes has to be linked from the company you bought your domain from to your server. 

Since every host is different If you don't know how to do this it's best to ask someone who does or pay someone for an hour's worth of time.

### WP Super Cache
WP Super Cache is a plugin for Wordpress that makes your site sometimes load much faster. It's totally fine if you use it. Howver, our server does its own caching so it needs to be able to get around the cache. It does this by using a specially crafter 'key'. You can generate it from the settings page on your Wordpress installation.

Steps to get key forthcoming here...