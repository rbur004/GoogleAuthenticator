#!/bin/sh
BASEDIR=$(dirname $0)

sudo gem install rotp
sudo gem install ruby-keychain 
sudo gem install clipboard
sudo gem install zbar
sudo gem install wikk_configuration
sudo gem install wikk_json
sudo gem install chunky_png
sudo gem install rqrcode

cd "$BASEDIR"
sudo /bin/cp -R GauthMenu.app /Applications/Utilities/
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Utilities/GauthMenu.app", hidden:false}' 

