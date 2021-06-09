# This file is to be executed inside a remote machine

sudo apt-get update

# yq
sudo wget https://github.com/mikefarah/yq/releases/download/v4.4.1/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq

# unzip
sudo apt-get install -y unzip
