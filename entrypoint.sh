#!/bin/bash    
bundle config build.nokogiri --use-system-libraries
bundle install --path vendor/bundle

# Write the logrotate file
cat >/etc/logrotate.conf <<EOL
/push/log/*.log {
  daily
  missingok
  rotate 7
  compress
  delaycompress
  notifempty
  copytruncate
}
EOL

# make sure the last run is cleared
rm /push/tmp/pids/server.pid

if [[ $RAILS_ENV = "development" ]]
then
	RAILS_ENV=development
	echo "Skipping precompile in development"
elif [[ $RAILS_ENV = "test" ]]
then
  RAILS_ENV=test
  echo "Skipping precompile in test"
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