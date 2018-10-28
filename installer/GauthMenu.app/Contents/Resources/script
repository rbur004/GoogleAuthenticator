#!/usr/bin/env ruby
require 'keychain'
require 'clipboard'
require 'rotp'
require 'chunky_png'
require 'zbar'
require 'uri'

#Turns Colour PNG into 8bit BW Y800 string.
# @param image [ChunckyPNG::Image]
# @return [String] Y800 image, as a string
def png_to_y800(image)
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

def save_key(issuer:, account:, key:)
  begin
  #google_authenticator = Keychain.open('googleauthenticator.keychain') #Could have private keychain
    Keychain.generic_passwords.create(:service => 'Google_Authenticator',    #fills in where field in keychain (and name, if no label)
  																	:password => key,                 #fills in name field in keychain.
  																	:account => "#{account}" ,             #fills in account field in keychain.
  																#	:comment => "#{issuer}",
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

def scan_qcode
  filename = `osascript -e 'tell application "System Events" to activate' -e 'tell application "System Events" to return POSIX path of (choose file with prompt "select an image file ")'`.chomp
  if filename != nil && filename != ''
    #puts "'#{filename}'"
    png_image = ChunkyPNG::Image.from_file(filename)
    #puts png_image.width, png_image.height
    y800_image = png_to_y800(png_image)
    zbar_image = ZBar::Image.new
    zbar_image.set_data(ZBar::Format::Y800, y800_image, png_image.width, png_image.height)
    begin
      text = URI.unescape(zbar_image.process[0].data)
    rescue Exception => error
      puts "Couldn't find code in image: #{error}"
      exit 1
    end
    #Google qrcode example otpauth://totp/Google%3Arbur004%40gmail.com?secret=ABCDEFGHIJKLMNOP&issuer=Google
    #UoA qrcode example otpauth://totp/rbur004@prod?secret=ABCDEFGHIJKLMNOP&issuer=The+University+of+Auckland
    puts text
    text.gsub( /^otpauth:\/\/totp\/(.*:)?(.*)\?secret=(.*)&issuer=(.*)$/, '' )
    save_key(issuer: $4, account: $2, key: $3)
    make_default_key(issuer: $4, account: $2)
  end
end

def read_qrcode
  text = `osascript -e 'tell application "System Events"' -e 'text returned of (display dialog "Enter QCode Text" default answer "otpauth://totp/Us?secret=ABCDEFGHIJKLMNOP&issuer=Them" buttons {"Cancel","OK"} default button 2 with title "$(basename $0)")' -e 'end tell'`.chomp
  if $? == 0 #Then button used was OK
    text.gsub( /^otpauth:\/\/totp\/(.*:)?(.*)\?secret=(.*)&issuer=(.*)$/, '' )
    save_key(issuer: $4, account: $2, key: $3)
    make_default_key(issuer: $4, account: $2)
  end
end

def output(text:)
  `osascript -e 'tell application "System Events"' -e 'set activeApp to name of first application process whose frontmost is true' -e 'if "Finder" is not in activeApp then' -e 'tell application activeApp' -e 'keystroke "#{text}"' -e 'end tell' -e 'end if' -e 'end tell'`
end

# If 0 arguments, we show menu
if ARGV.length == 0
  output = []
  Keychain.generic_passwords.where(:service => 'Google_Authenticator').all.each do |p|
    output << p
  end
  output.sort_by! { |p| [p.label, p.account] }
  output.each { |p| puts "#{p.label} #{p.account}" }
  puts "-------------------------------"
  puts "Scan"
  puts "Manual-Input"
else #Get the key
  if ARGV[0] == 'Scan'
    scan_qcode
  elsif ARGV[0] == 'Manual-Input'
      read_qrcode
  elsif ARGV[0] != "-------------------------------"
    label, account = ARGV[0].split(' ')
    Keychain.generic_passwords.where(:service => 'Google_Authenticator', :account => account, :label => label).all.each do |p|
      totp = ROTP::TOTP.new( p.password )
      result = totp.now
      #Clipboard.copy  result
      output(text: result)
    end
  end
end
