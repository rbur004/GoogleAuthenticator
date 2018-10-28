# GauthMenu

* Source https://github.com/rbur004/googleauthenticator

## DESCRIPTION:

  All these equire the user password to access the Mac OS X keychain.
  
  gauth inserts the latest google authenticator key into the clipboard, for the provider and account specified as arguments.
  gauth_auto inserts the latest google authenticator key into the clipboard, for the provider and account specified in ~/.gauth.
  gauth_config creates Mac OS X keychain entries for the provider, account and key specified as arguments.

  gauth_menu.rb is a Platypus script to create a Mac OS X menu, which shows all the current keys stored in the keychain.
  Injects the latest google authenticator key into the keyboard buffer (i.e. it looks like it was typed), for the provider and account selected.
  Can scan Google Authenticator QRCodes, and store the provider, account and key in the Mac OS X keychain.
  Can also accept manual entry of the provider, account and key in a dialog box. 
  This must be in the form of otpauth://totp/user@site?secret=KEY_STRING&issuer=Provider_name (with no spaces)

  ruby-setup.sh installs the gems, and copies the GauthMenu.app application (created by Platypus from the gauth_menu.rb script) into Utilities, and adds this as a startup item for the user.
 
### Under Experimental:

  create_qr_code.rb reads google authenticator keys from the Mac OS X keychain, and the user can select one to print as a QRCode. Requires the user password to access the keychain.
  
  read_all_keys.rb reads google authenticator keys from the Mac OS X keychain, and prints them to standard out. Requires the user password to access the keychain.
 
## FEATURES/PROBLEMS:


## SYNOPSIS:

Google Authenticator menu item for Mac OS X. 

	
## REQUIREMENTS:

	To create the application, Platypus.
	Mac OS X
	Ruby
	
## INSTALL:

	* Mac OS X GauthMenu.app application is in the repository, and is the only bit I now use.
	
Older, and not needed with GauthMenu.app
	*          Scan QRCode.app is also in the repository. 
	*          GoogleAuthenticator.app Runs and closes, leaving default provider accounts one time key in the clipboard.
	
From ruby-setup.sh, which will do the following, and copy GauthMenu to Utilities and add it as a login item.
	* sudo gem install rotp
  * sudo gem install ruby-keychain 
  * sudo gem install clipboard
  * sudo gem install zbar
  * sudo gem install wikk_configuration
  * sudo gem install wikk_json
  * sudo gem install chunky_png
  * sudo gem install rqrcode
  
	
## LICENSE:

(The MIT License)

Copyright (c) 2016 Rob Burrowes

1. You may make and give away verbatim copies of the source form of the
   software without restriction, provided that you duplicate all of the
   original copyright notices and associated disclaimers.

2. You may modify your copy of the software in any way, provided that
   you do at least ONE of the following:
    *  place your modifications in the Public Domain or otherwise make them Freely Available, such as by posting said modifications to Usenet or an equivalent medium, or by allowing the author to include your modifications in the software.
    *  use the modified software only within your corporation or organization.
    *  rename any non-standard executables so the names do not conflict with standard executables, which must also be provided.
    *  make other distribution arrangements with the author.

3. You may distribute the software in object code or executable form, provided that you do at least ONE of the following:
    * distribute the executables and library files of the software,
  together with instructions (in the manual page or equivalent)
  on where to get the original distribution.
    * accompany the distribution with the machine-readable source of
  the software.
    * give non-standard executables non-standard names, with
        instructions on where to get the original software distribution.
    * make other distribution arrangements with the author.

4. You may modify and include the part of the software into any other
   software (possibly commercial).  But some files or libraries used by
   code in this distribution  may not written by the author, so that they 
   are not under these terms.

5. The scripts and library files supplied as input to or produced as 
   output from the software do not automatically fall under the
   copyright of the software, but belong to whomever generated them, 
   and may be sold commercially, and may be aggregated with this
   software.

6. THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
   IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
   PURPOSE.
