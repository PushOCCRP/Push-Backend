# Push-Backend
## Introduction
This operates as a middleman between the plugin installed on the CMS and the apps. It provides a consistant API for the mobile apps to connect to while also sanitizing, caching, routing and doing general best practices on the HTML coming out of the CMS.

This app is set up to run on Docker, which handles 90% of the set up for the database and such. The main thing a user has to worry about is setting up the SSL certificates and the APNS (Apple Push Notification Service) and GCM (Google Push) certs.

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

# Running
After setting up the secrets.env file, ```docker-compose up``` should be all you need to run the project (if you have Docker installed). Make sure you have port 443 open for incoming connections.