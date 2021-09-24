#!/usr/local/ruby/bin/ruby
require 'keychain'
require 'chunky_png'
require 'zbar'
require 'uri'
require 'cgi'

# First attempt at scanning a QRCode and injecting the result into the Mac OS X keychain.
# Created "Scan Qcode.app" from this script, using Platypus.
# Asks for the keychain password when run.

# Turns Colour PNG into 8bit BW Y800 string.
# @param image [ChunckyPNG::Image]
# @return [String] Y800 image, as a string
def png_to_y800(image:)
  y800 = ''
  (0...image.height).each do |h|
    (0...image.width).each do |w|
      v = image[w, h]
      y800 << ((((ChunkyPNG::Color.r(v) * 0.21) + (ChunkyPNG::Color.g(v) * 0.72) + (ChunkyPNG::Color.b(v) * 0.07)).round ) & 0xFF ).chr
    end
  end
  return y800
end

# save_key saves the google authenticator details into the Mac OS X Keychain. (Mac prompts for the users password to do this)
# @param issuer [String] No spaces. This is the company that the google authenticator key is for
# @param account [String] Usually in the form of user@x.com to identify the account
# @param key [String] This is the secret that is used to generate the one time keys.
def save_key(issuer:, account:, key:)
  begin
    # Keychain looks to be using (account,service) as it's unique key. Adding fails silently if there is a collision.
    # Therefore, we will always ensure account is of the form account@issuer (unless account is already qualified with a domain name)
    issuer = issuer.split('@')[1] if issuer =~ /@/        # Set issuer to the domain part, if it is in the form user@domain style
    account = "#{account}@#{issuer}" # if account !~ /@/  # Set Account to account@issuer, even if the is no @ in the account string

    Keychain.generic_passwords.create(service: 'Google Authenticator', # fills in where field in keychain (and name, if no label)
                                      password: key, # fills in name field in keychain.
                                      account: "#{account}", # fills in account field in keychain.
                                      # :comment => "#{issuer}",
                                      label: "#{issuer}"
                                     ) # fills in name field in keychain.
  rescue Keychain::DuplicateItemError => _e
    begin
      Keychain.generic_passwords.where(service: 'Google Authenticator', account: "#{account}", label: "#{issuer}").all.each do |p|
        p.password = key
        p.save!
      end
    rescue StandardError => error
      puts error
      exit 2
    end
  rescue StandardError => e
    puts e
    exit 2
  end
end

# make_default_key stores the provider/issuer and account details of the default google account
# in ~/.gauth. This allows for a simple open and close immediately app, that leaves the one time key in the clipboard.
# @param issuer [String] The provider or issuing company
# @param account [String] The account at the provider. Usually of for user@company.com
def make_default_key(issuer:, account:)
  action = `osascript -e 'tell app "System Events" to return button returned of ( display dialog "Make this account the default" buttons {"No", "Yes"} default button 1 with title "GoogleAuthenticator")'`.strip
  if action == 'Yes'
    File.open(File.expand_path('~/.gauth'), 'w') do |fd|
      fd.puts <<~EOF
        {
          "label": "#{issuer}",
          "account": "#{account}"
        }
      EOF
    end
  end
end

# Parse an atpauth:// URI string to extract the arguments from it
# @return otp auth arguments as a hash
def parse_otpauth(uri:)
  arguments = {}
  first_split = uri.split('/')
  # first_split[0] would be 'otpauth:', [1] would be '', [2] would be org and user and the arguments
  second_split = first_split[3].split('?')
  # Second split [0] would be the org and user, [1] would be the arguments
  arguments['user'] = second_split[0].split(':')[-1] # Last entry should be the user. There might not be an org in the URI
  second_split[1].split('&').each do |a| # Other arguments are after the '?'
    key, value = a.split('=')
    arguments[key] = value
  end
  return arguments
end

# Use Applescript to let user select the QRCode image to scan.
filename = `osascript -e 'tell application "System Events" to activate' -e 'tell application "System Events" to return POSIX path of (choose file with prompt "select an image file ")'`.chomp
if filename != nil && filename != ''
  png_image = ChunkyPNG::Image.from_file(filename)
  y800_image = png_to_y800(image: png_image)
  zbar_image = ZBar::Image.new
  zbar_image.set_data(ZBar::Format::Y800, y800_image, png_image.width, png_image.height)
  begin
    text = CGI.unescape(zbar_image.process[0].data)
  rescue StandardError => e
    puts "Couldn't find code in image: #{e}"
    exit 1
  end
  # Google qrcode example otpauth://totp/Google%3Arbur004%40gmail.com?secret=ABCDEFGHIJKLMNOP&issuer=Google
  puts text
  arguments = parse_otpauth(uri: text)
  puts "issuer: #{arguments['issuer']}, account: #{arguments['user']}, key: #{arguments['secret']}"
  save_key(issuer: arguments['issuer'], account: arguments['user'], key: arguments['secret'])
  # make_default_key(issuer: arguments['issuer'], account: rguments['user'])
end
