#!/usr/local/bin/ruby
# Add passwords to the keychain
require 'keychain'

keys = [

  { label: 'x.com', account: 'me', password: 'fredwashere', where: 'Service_type' }
]

keys.each do |k|
  begin
    Keychain.generic_passwords.create(service: k[:where], # fills in where field in keychain (and name, if no label)
                                      password: k[:password], # fills in name field in keychain.
                                      account: k[:account], # fills in account field in keychain.
                                      # :comment => "#{issuer}",
                                      label: k[:label]
                                     ) # fills in name field in keychain.
  rescue Keychain::DuplicateItemError
    # Ignore duplicates
  end
end
