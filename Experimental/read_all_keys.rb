#!/usr/local/bin/ruby
require 'keychain'

#Test, by reading it back keys. Will get prompted for local account password by Mac OS X.
#Keychain.generic_passwords.where(:service => 'Google_Authenticator', :account => "#{account}").all.each do |p|
#rbur004=Keychain.open('googleauthenticator.keychain')

Keychain.generic_passwords.where(:service => 'Google_Authenticator').all.each do |p|
  begin
    puts "#{p.label}, #{p.account}, #{p.password}"
  rescue Exception => e
    puts "error: e"
  end
end

