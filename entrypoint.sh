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
FILE=/push/tmp/pids/server.pid
if test -f "$FILE"; then
  echo "Previous PID file found @ $FILE"
  echo "Deleting PID file..."
  rm /push/tmp/pids/server.pid
fi

echo ""
echo "Booting Rails in $RAILS_ENV mode"
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
	bundle exec rake assets:precompile
	echo "Done."
fi

echo "Checking database status... 🔎"
output="$(bundle exec rake db:abort_if_pending_migrations 2>&1 | grep -ci "ActiveRecord::NoDatabaseError")"
if [[ $output = "1" ]]
then
  echo "Database not found, creating it now..."
  bundle exec rake db:create
  echo "Database created, moving onward 🎈"
else
  echo "Database exists, moving onward ➡️"
fi

echo "Checking database migration status..."
output="$(bundle exec rake db:abort_if_pending_migrations 2>&1 | grep -ci "update your database then try again.")"
if [[ $output = "1" ]]
then
  echo "Database not up to date, running migrations..."
  bundle exec rake db:migrate
  echo "Database migrated, going forward 🎈"
else
  echo "Database up to date, going forward ➡️"
fi

echo "Database checks all done! 🔥"
echo "If you're on a mac, please wait for awhile now..."

exec $@
