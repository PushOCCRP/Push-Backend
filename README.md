# Push-Backend
## Introduction
This operates as a middleman between the plugin installed on the CMS and the apps. It provides a consistant API for the mobile apps to connect to while also sanitizing, caching, routing and doing general best practices on the HTML coming out of the CMS.

This app is set up to run on Docker, which handles 90% of the set up for the database and such. The main thing a user has to worry about is setting up the APNS (Apple Push Notification Service) and Firebase certs.

## Overview
This consists of five systems.
- Web
-- This is the main Ruby on Rails 5.1.2 app. It's an utterly standard Rails app which uses Puma as the front server for multithreading and such.
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
#### (Skip to next section if you're using the AWS setup [scripts](https://github.com/PushOCCRP/Push-AWS-Launcher)

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
1. Set up the CMS environment variables. ```bash maintence-scripts/setup-cms_env.sh```
1. Run the set up scripts ```bash ./maintence-scripts/setup-lets_encrypt.sh```
1. From here there will be a bunch of questions to answer, it should be quite self explanatory
1. Generate a secure key for the web server. ```docker-compose -f letsencrypt-docker-compose.yml run -e NGINX_BOOT=false nginx```
1. Be patient, there's a bunch of stuff going on here including building a bunch of different Docker containers, and creating SSL keys, which can take A LONG time. It really depends on the machine. If you're on an AWS micro instance go for a run, take a shower, whatever, you have at least 45 minutes, maybe two hours to kill.
1. (Again) Be patient, there's a bunch of stuff going on here including building a bunch of different Docker containers, and creating SSL keys, which can take A LONG time. It really depends on the machine. If you're on an AWS micro instance go for a run, take a shower, whatever, you have at least 45 minutes, maybe two hours to kill.
1. Run the final script to set up all the databases ```sudo bash maintence-scripts/setup-databases.sh```
1. Generate different secure keys for the web server. ```sudo docker-compose -f letsencrypt-docker-compose.yml up letsencrypt```
1. After waiting far too long, run ```sudo docker-compose up``` and everything should build and boot automatically. You'll get a bunch of weird errors from the ```nginx``` containter. This is fine.
1. Close it all out by pressing ```ctrl-c```
1. Rerun the lets encrypt again ```sudo docker-compose -f letsencrypt-docker-compose.yml up letsencrypt```
1. This part is slightly confusing, but I haven't figured out a way around. The previous steps create the SSL keys, but put them in the wrong folder. First, we need to move the certificates to the right place ```sudo mv .docker/data/secrets/keys/live/<<your host name>>-0001/* .docker/data/secrets/keys/live/<<your host name>>``` example is ```sudo mv .docker/data/secrets/keys/live/example.pushapp.press-0001/* .docker/data/secrets/keys/live/example.pushapp.press```.
1. Now we remove the old folder ```sudo rm -r .docker/data/secrets/keys/live/example.pushapp.press-0001```
1. __Really__ run docker-compose now ```sudo docker-compose up```
1. If all is good ```ctrl-c``` to close down. Then run ```docker-compose up -d``` to start in the background
1. At this point you're good to go. You can exit your server and rest easy.
1. If you're seeing any errors here try and restarting the box and running ```docker-compose up``` again. It may fix it.

# Running
After following the steps above, ```docker-compose up -d``` should be all you need to run the project.

Please make sure there is a symlink named `docker-compose.yml` in the main project directory, linking ether to `docker-compose-with-nginx.yml` (the default, if in doubt, use that), or `docker-compose-no-nginx.yml` (for bigger deployments that have their own `nginx` or other front-end webserver running somewhere already). The `setup.sh` maintenance script should set it up for you.

# Troubleshooting

- If you get an error like ```ERROR: Couldn't connect to Docker daemon at http+docker://localunixsocket - is it running?``` check that your user is in the ```docker``` group. To do that run ```groups $USER``` If it is, log out and logging back in should fix the problem.

- If you're having troubles connecting from your browser, make sure that you have port 443 open to incoming traffic on the server.

# Setting Up Push Notifiations
For our project we use a system called Uniqush. This is an open sourced push notification manager that lets us manage the system without paying or using a service such as Urban airship. Because iOS and Android use different systems we need to set them up seperately, but in the end this will let us send the same message to all devices.

## Local Development
If you're trying to set up this for local development the SSL keys get a bit off. There's two options
1. Use the `docker-compose-no-nginx-dev.yml` docker-compose file (preferred unless you know what you're doing).
1. Set up the Lets Encrypt certs yourself. Instructions are coming for this method.

#### Local Mac Setup

1. Install LetsEncrypt's Certbot tool `brew install letsencrypt`
1. Generate basic cert `sudo certbot certonly --standalone`
  - If you get an error like "Problem binding to port 80: Could not bind to IPv4 or IPv6." on a mac try `sudo apachectl stop`.
  - Afterwards if `curl localhost:80` returns `curl: (7) Failed to connect to localhost port 80: Connection refused` then try again.
1. Copy the certs from the folders listed in the export to the appropriate `.docker` folder.
  - `sudo mkdir ./.docker/data/secrets/keys/live/test.pushapp.press`
  - `sudo cp /etc/letsencrypt/live/test.pushapp.press/fullchain.pem ./.docker/data/secrets/keys/live/test.pushapp.press/fullchain.pem`
  - `sudo cp /etc/letsencrypt/live/test.pushapp.press/privkey.pem ./.docker/data/secrets/keys/live/test.pushapp.press/privkey.pem`
1. Make sure the permsissions are set right `sudo chmod -R 644 ./.docker/data/secrets/keys/live/test.pushapp.press/`

### iOS

1. This is done using the generator scripts. Specifically run the generator with the -c command and it will create and convert the files for you automatically.

1. From the back end go to "Notifications" -> "Preferences" and click "APNS Cert Upload".

1. Click "Browse" and go the folder where your generator scripts are. In here the certificates are saved to /credentials/push/ios/[name of your app]/. For the "Cert" field choose the filed that ends in "\_cert.pem". For the "Key" field choose the field that ends in "\_key.pem"

1. Click "Save"

### Android

1. Go to https://console.firebase.google.com and log in.

1. Click the big button that says "Add Project"

1. In the popup type in the name for your project, choose your country, and then click "Create Project"

1. If you're not taken directly to the new project just click the box that pops up with the name on it.

1. From the "Overview" page look to the upper-left corner and click the "settings" sprocket and then click "Project settings".

1. From the backend of your app go to "Notifications" -> "Preferences" and click "GCM Management". **Note:** This now uses Google's Firebase but I haven't gotten around to changing the labels yet.

1. Going back to the Firebase Console you should see a bunch of identifying information. Copy the text next to "Project ID". It will be a version of your apps name with dashes like ```sample-push-app```

1. Go back to your apps backend and paste it into the "Project ID" field.

1. Going back to Firebase click on the second tab "Cloud Messaging".

1. From here copy the very long string next to "Server key"

1. Going back to the backend again paste this string into the "Legacy gcm api key" **Note:** The same as above applies here.

1. Click "Save"

# Notes

### DNS HOST
A DNS host entry is what tells the internet that your URL (e.g. https://www.example.com) points to your server's IP (e.g. 192.168.1.1). Depending on your hosting company this is can be set automatically or sometimes has to be linked from the company you bought your domain from to your server.

Since every host is different If you don't know how to do this it's best to ask someone who does or pay someone for an hour's worth of time.

### WP Super Cache
WP Super Cache is a plugin for Wordpress that makes your site sometimes load much faster. It's totally fine if you use it. Howver, our server does its own caching so it needs to be able to get around the cache. It does this by using a specially crafter 'key'. You can generate it from the settings page on your Wordpress installation.

Steps to get key forthcoming here...

# Development

## Setup Instructions

### Mac
Developmet on a Mac is a bit tiresome, mostly because getting the containers running means waiting a
long time for them to boot (it's a Mac only thing, no idea why).

A few other things,
1. Before you run bundle install the first time you'll need to install the libmagic library.
   This is best done using [Homebrew](https://brew.sh/), so set that up if you don't have it already
   then run `brew install libmagic`

## Adding Support For New CMS

#### Model

For every CMS backend that Push supports there is a corresponding model that inherets from the ```CMS``` class found in ```/app/models/cms.rb```.

There are three methods that have to be implemented:

- ```def self.articles params```
- ```def self.article params```
- ```def self.search params```

If you implement categories you must also implement

- ```def self.categories```

How you decided to implement these is mostly up to you, since every CMS does it differently. There are formatting helpers and standard HTML/CSS/JS cleaners in the ```CMS``` class. I would recommend looking at the various other implementations of cms models to get a feel for how they work.

#### Controller

For every CMS you need to add a switch so that the controller knows which model to use. Right now that's here in the ```/app/controllers/articles_controller.rb``` file:

- ```def index```
- ```def search```
- ```def article```

There are some leftover stuff from Joomla in the Controller but you can ignore it for implementation purposes.

You also need to add a new switch to the ```check_for_valid_cms_mode``` in ```/app/controllers/application_controller.rb```

#### Environment Variables

Push uses the [Figaro](https://github.com/laserlemon/figaro) gem for configuation. The config file is at ```/config/initializers/figaro.rb```.

Specifically you have to choose a name for the ```cms_mode``` and then the required variables. This is at least a url for the cms but could be things such as API keys as well.

#### Scripts

As a final help to the community, you shoul add your CMS to the setup scripts as an option. That's found in ```./maintence-scripts/setup-cms_env.sh``` (starting around line 30)

---

## API

The Push Backend serves up an API that can be consumed by Push client apps. Right now that's only the iOS and Android apps, but could be things such as TV apps or other readers.

Here are the main consumption APIs, there's a few other that I have yet to document, but they are for internal purposes and are not needed by the apps.

### Parameters

These parameters are applicable for all requests.

- _language_ (optional): a two letter language code (e.g. 'en', 'de', 'sr'). This raises an error if the language is not enabled.

### Responses

TBD

---

### Get All Articles

#### Verb

GET

#### Path

/articles

#### Required Headers

- Accept: application/json

#### Parameters

- _categories_ (optional): ```true``` or ```false``` if you would like cateogries or consolidated listings. If categories is disabled in the backend this will not matter.

### Get Single Article

#### Verb

GET

#### Path

/article

#### Required Headers

- Accept: application/json

#### Parameters

- _id_ (required): The article id that represents the article in the backend CMS.

#### Discussion

Since the Push backend does not keep track of individual articles the ```id``` is whatever is assigned in the main CMS.

This is mostly used to respond to push notifications.

### Search

#### Verb

GET

#### Path

/search

#### Required Headers

- Accept: application/json

#### Parameters

- _q_ (required): The query, html encoded, to search for.





