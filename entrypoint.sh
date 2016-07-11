#!/bin/bash    
bundle config build.nokogiri --use-system-libraries
bundle install --path vendor/bundle

# make sure the last run is cleared
rm /push/tmp/pids/server.pid
echo "bundle done"
#if psql -lqt | cut -d \| -f 1 | grep -qw 'development'; then
#    echo "database already exists"
#else
#	rake db:create
#fi

#rake db:reset
#rake db:migrate

exec $@
