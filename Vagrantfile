# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-20.04"

  config.vm.network(:forwarded_port, guest: 3000, host: 3000)
  config.vm.network(:forwarded_port, guest: 9898, host: 9898)

  $script = <<-SCRIPT
  echo "Updating sources..."
  apt-get update
  echo "Installing Docker..."
  apt-get install -qq docker.io
  curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose

  echo "Building Docker dev containers..."
  docker-compose --file=/docker/docker-compose-no-nginx-dev.yml build

  SCRIPT

  config.vm.synced_folder ".", "/docker"
  config.vm.provision "shell", inline: $script
end
