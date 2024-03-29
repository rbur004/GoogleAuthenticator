#!/usr/local/bin/ruby
require 'keychain'
require 'clipboard'
require 'rotp'
require 'chunky_png'
require 'zbar'
require 'uri'
require 'cgi'

require 'rb-scpt'
include Appscript

# Turns Colour PNG into 8bit BW Y800 string.
# @param image [ChunckyPNG::Image]
# @return [String] Y800 image, as a string
def png_to_y800(image)
  y800 = ''
  (0...image.height).each do |h|
    (0...image.width).each do |w|
      v = image[w, h]
      y800 << (((ChunkyPNG::Color.r(v) * 0.21) + (ChunkyPNG::Color.g(v) * 0.72) + (ChunkyPNG::Color.b(v) * 0.07)).round & 0xFF).chr
    end
  end
  return y800
end

def save_key(issuer:, account:, key:)
  begin
    # google_authenticator = Keychain.open('googleauthenticator.keychain') #Could have private keychain

    # Keychain looks to be using (account,service) as it's unique key. Adding fails silently if there is a collision.
    # Therefore, we will always ensure account is of the form account@issuer (unless account is already qualified with a domain name)
    issuer = issuer.split('@')[1] if issuer =~ /@/      # Set issuer to the domain part, if it is in the form user@domain style
    account = "#{account.gsub(/@.*$/, '')}@#{issuer}"   # Set Account to account@issuer, which should be unique.

    Keychain.generic_passwords.create(service: 'Google Authenticator', # fills in where field in keychain (and name, if no label)
                                      password: key, # fills in name field in keychain.
                                      account: account.to_s, # fills in account field in keychain.
                                      #	:comment => "#{issuer}",
                                      label: issuer.to_s
                                     ) # fills in name field in keychain.
  rescue Keychain::DuplicateItemError => _e
    begin
      Keychain.generic_passwords.where(service: 'Google Authenticator', account: account.to_s, label: issuer.to_s).all.each do |p|
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

# Ask if the user wants to make this the default key
# The default is used by the GoogleAuthenticator app, which asks for no input.
# @param issuer [String] Google authenticator key's issuer (From the QRCode)
# @param account [String] Google authenticator key's user account name (from the QRcode)
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

# Read Google authenticator key from a QRCode and save the resulting issure, user and key into the Apple keystore.
def scan_qcode
  filename = `osascript -e 'tell application "System Events" to activate' -e 'tell application "System Events" to return POSIX path of (choose file with prompt "select an image file ")'`.chomp
  if filename != nil && filename != ''
    # puts "'#{filename}'"
    png_image = ChunkyPNG::Image.from_file(filename)
    # puts png_image.width, png_image.height
    y800_image = png_to_y800(png_image)
    zbar_image = ZBar::Image.new
    zbar_image.set_data(ZBar::Format::Y800, y800_image, png_image.width, png_image.height)
    begin
      text = CGI.unescape( zbar_image.process[0].data )
    rescue StandardError => e
      puts "Couldn't find code in image: #{e}"
      exit 1
    end

    puts text
    arguments = parse_otpauth(uri: text)
    save_key(issuer: arguments['issuer'], account: arguments['user'], key: arguments['secret'])
    make_default_key(issuer: Regexp.last_match(4), account: Regexp.last_match(2))
  end
end

# Read the Google Authenticator key details from a dialog box, rather than a QRcode. Save these into the Apple keystore
def read_qrcode
  text = `osascript -e 'tell application "System Events"' -e 'text returned of (display dialog "Enter QCode Text" default answer "otpauth://totp/Us?secret=ABCDEFGHIJKLMNOP&issuer=Them" buttons {"Cancel","OK"} default button 2 with title "$(basename $0)")' -e 'end tell'`.chomp
  if $CHILD_STATUS == 0 # Then button used was OK
    arguments = parse_otpauth(uri: text)
    save_key(issuer: arguments['issuer'], account: arguments['user'], key: arguments['secret'])
    make_default_key(issuer: Regexp.last_match(4), account: Regexp.last_match(2))
  end
end

# Insert the text into the keyboard buffer, so it looks as if we typed it.
# text [String] text we want to 'type' on the keyboard.
def output_osa(text:)
  `osascript -e 'tell application "System Events"' -e 'set activeApp to name of first application process whose frontmost is true' -e 'if "Finder" is not in activeApp then' -e 'tell application activeApp' -e 'keystroke "#{text}"' -e 'end tell' -e 'end if' -e 'end tell'`
end

def output(text:)
  se = app('System Events')
  a = se.processes[its.frontmost.eq(true)]
  a.keystroke(text)
end
# Parse an atpauth:// URI string to extract the arguments from it
#
# Google qrcode example otpauth://totp/Google%3Arbur004%40gmail.com?secret=ABCDEFGHIJKLMNOP&issuer=Google
# UoA qrcode example otpauth://totp/rbur004@prod?secret=ABCDEFGHIJKLMNOP&issuer=The+University+of+Auckland
# NeSI one mixes up the fields and adds additional fields
# otpauth://totp/rbur004@NESI.ORG.NZ:rbur004?digits=6&secret=ABCDEFGHIJKLMNOP&period=30&algorithm=SHA1&issuer=rbur004@NESI.ORG.NZ
#
# @param uri [String] otpauth URI string
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

# If 0 arguments, we show menu.
# Otherwise we lookup the google authenitcator key from the apple keystore and generate a one time code, inserting it into the key buffer.
if ARGV.length == 0
  output = []
  Keychain.generic_passwords.where(service: 'Google Authenticator').all.each do |p|
    output << p
  end
  output.sort_by! { |p| [ p.label, p.account ] }
  output.each { |p| puts "#{p.label} #{p.account}" }
  puts '-------------------------------'
  puts 'Scan'
  puts 'Manual-Input'
elsif ARGV[0] == 'Scan' # Get the key
  scan_qcode
elsif ARGV[0] == 'Manual-Input'
  read_qrcode
elsif ARGV[0] != '-------------------------------'
  label, account = ARGV[0].split
  Keychain.generic_passwords.where(service: 'Google Authenticator', account: account, label: label).all.each do |p|
    totp = ROTP::TOTP.new( p.password )
    result = totp.now
    Clipboard.copy( result )
    output(text: result)
  end
end
