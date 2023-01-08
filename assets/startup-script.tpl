#!bin/bash

sudo apt update -y
sudo apt install python3-pip python3-dev build-essential libssl-dev libffi-dev python3-setuptools -y 

pip install flask -y
pip install wheel -y 
pip install gunicorn flask -y 

sudo apt-get install python3-mysqldb -y
