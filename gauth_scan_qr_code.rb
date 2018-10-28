#!/usr/bin/env ruby
require 'keychain'
require 'chunky_png'
require 'zbar'
require 'uri'

#First attempt at scanning a QRCode and injecting the result into the Mac OS X keychain.
#Created "Scan Qcode.app" from this script, using Platypus.
#Asks for the keychain password when run.

#Turns Colour PNG into 8bit BW Y800 string.
# @param image [ChunckyPNG::Image] 
# @return [String] Y800 image, as a string
def png_to_y800(image:)
  y800 = ""
  (0...image.height).each do |h|
    (0...image.width).each do |w|
      v = image[w,h]
      y800 << (((ChunkyPNG::Color::r(v) * 0.21  + 
                ChunkyPNG::Color::g(v) * 0.72 + 
                ChunkyPNG::Color::b(v) * 0.07).round ) & 0xFF ).chr
    end
  end
  return y800
end

#save_key saves the google authenticator details into the Mac OS X Keychain. (Mac prompts for the users password to do this)
# @param issuer [String] No spaces. This is the company that the google authenticator key is for
# @param account [String] Usually in the form of user@x.com to identify the account
# @param key [String] This is the secret that is used to generate the one time keys.
def save_key(issuer:, account:, key:)
  begin
    Keychain.generic_passwords.create(:service => 'Google_Authenticator',    #fills in where field in keychain (and name, if no label)
                                    :password => key,                 #fills in name field in keychain.
                                    :account => "#{account}" ,             #fills in account field in keychain.
                                  # :comment => "#{issuer}",
                                    :label => "#{issuer}")                 #fills in name field in keychain.
  rescue Keychain::DuplicateItemError => error
    begin
      Keychain.generic_passwords.where(:service => 'Google_Authenticator', :account => "#{account}", :label => "#{issuer}").all.each do |p|
        p.password = key
        p.save!
      end
    rescue Exception => error
      puts error
      exit 2
    end
  rescue Exception => error
    puts error
    exit 2
  end
end

#make_default_key stores the provider/issuer and account details of the default google account
#in ~/.gauth. This allows for a simple open and close immediately app, that leaves the one time key in the clipboard.
# @param issuer [String] The provider or issuing company
# @param account [String] The account at the provider. Usually of for user@company.com
def make_default_key(issuer:, account:)
  action = `osascript -e 'tell app "System Events" to return button returned of ( display dialog "Make this account the default" buttons {"No", "Yes"} default button 1 with title "GoogleAuthenticator")'`.strip
  if action == 'Yes'
    File.open(File.expand_path("~/.gauth"), "w") do |fd|
      fd.puts <<-EOF
{
  "label": "#{issuer}",
  "account": "#{account}"
}
EOF
    end
  end
end

#Use Applescript to let user select the QRCode image to scan.
filename = `osascript -e 'tell application "System Events" to activate' -e 'tell application "System Events" to return POSIX path of (choose file with prompt "select an image file ")'`.chomp
if filename != nil && filename != ''
  png_image = ChunkyPNG::Image.from_file(filename)
  y800_image = png_to_y800(image: png_image)
  zbar_image = ZBar::Image.new
  zbar_image.set_data(ZBar::Format::Y800, y800_image, png_image.width, png_image.height)
  begin
    text = URI.unescape(zbar_image.process[0].data)
  rescue Exception => error
    puts "Couldn't find code in image: #{error}"
    exit 1
  end
  #Google qrcode example otpauth://totp/Google%3Arbur004%40gmail.com?secret=ABCDEFGHIJKLMNOP&issuer=Google
  text.gsub( /^otpauth:\/\/totp\/(.*:)?(.*)\?secret=(.*)&issuer=(.*)$/, '' )
  save_key(issuer: $4, account: $2, key: $3)
  #make_default_key(issuer: $4, account: $2)
end
