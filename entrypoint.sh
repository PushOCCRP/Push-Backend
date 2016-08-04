#!/bin/bash    
bundle config build.nokogiri --use-system-libraries
bundle install --path vendor/bundle

# make sure the last run is cleared
rm /push/tmp/pids/server.pid

if [[ $RAILS_ENV = "development" ]]
then
	RAILS_ENV=development
	echo "Skipping precompile in development"
else
        RAILS_ENV=production
	echo "Precompiling assets..."
	rake assets:precompile 
	echo "Done."
fi

#if psql -lqt | cut -d \| -f 1 | grep -qw 'development'; then
#    echo "database already exists"
#else
#	rake db:create
#fi

#rake db:reset
#rake db:migrate

exec $@
