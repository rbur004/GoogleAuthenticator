#!/usr/local/bin/ruby
require 'keychain'
require 'rqrcode'

#Read the keys from the Mac OS X keychain.  Will get prompted for local account password by Mac OS X.
#Offer a selection menu to the user to pick one
#Create a QRCode png file from the key selected.


#Create a QRCode PNG file for Google Authenticator
# @param account [String] Just a comment. Shows up in Google authenticator to identify the specific account for this issure
# @param issuer [String] Just a comment. Shows up in google authenticator to identify the issure of the account
# @param secret [String] The important bit, as generated by rotp.
def create_qrcode(account: 'user@somewhere.com', issuer: 'Company-Name', secret: 'as_if_i_would_tell')
  qrcode = RQRCode::QRCode.new("otpauth://totp/#{account}?secret=#{secret}&issuer=#{issuer.gsub(/\s/,'_')}")
  # With default options specified explicitly
  png = qrcode.as_png(
            resize_gte_to: false,
            resize_exactly_to: false,
            fill: 'white',
            color: 'black',
            size: 120,
            border_modules: 4,
            module_px_size: 6,
            file: nil # path to write
            )
          
  #Tried using Applescript POSIX convertor, but it always gave an error. Hence the .gsub(/^file /,'/Volumes/').gsub(/:/,'/') conversion.
  filename = `osascript -e 'tell application "System Events" to activate' -e 'tell application "System Events" to return (choose file name with prompt "Save the QCode as:" default name "#{issuer}.png" default location path to desktop)'`.chomp.gsub(/^file /,'/Volumes/').gsub(/:/,'/')

  IO.write(filename, png.to_s) if filename != nil && filename != ''
end


#query_user_for_provider_and_account
# @return [Boolean,] true if we selected an account. False if we cancelled.
def query_user_for_provider_and_account
  output = []
  Keychain.generic_passwords.where(:service => 'Google_Authenticator').all.each do |p|
    output << p
  end
  output.sort_by! { |p| [p.label, p.account] }
  list = []
  output.each { |p| list << "#{p.label} #{p.account}" }

  #Selection menu using Applescript.
  key = `osascript -e 'tell application "System Events" to activate' -e 'tell application "System Events" to set keyList to {"#{list.join('","')}"}' -e 'tell application "System Events" to return ( choose from list keyList with title "keys" )'`
  
  return $? == 0 ? [true] + key.split(' ') : [false, '', '']
end

selected, provider, account = query_user_for_provider_and_account
#If we didn't cancel, then create the QRCode png file.
if selected
  #Read the google authenticator keys from the keychain.
  Keychain.generic_passwords.where(:service => 'Google_Authenticator', :account => account, :label => provider).all.each do |p|
    create_qrcode(account: account, issuer: provider, secret: p.password)
    break
  end
end



