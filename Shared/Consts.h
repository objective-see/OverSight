//
//  Consts.h
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

//TODO: update!

#ifndef WYS_Consts_h
#define WYS_Consts_h

//success
#define STATUS_SUCCESS 0

//product url
#define PRODUCT_URL @"https://objective-see.com/products/whatsyoursign.html"

//installed extensions
#define INSTALLED_EXTENSIONS @"~/Library/Preferences/com.apple.preferences.extensions.FinderSync.plist"

//bundle ID of finder sync extension
#define EXTENSION_BUNDLE_ID @"com.objective-see.WhatsYourSignExt.FinderSync"

//extension folder
#define EXTENSION_FOLDER @"~/Library/WhatsYourSign"

//extension name
#define EXTENSION_NAME @"WhatsYourSign.appex"

//frame shift
// ->for status msg to avoid activity indicator
#define FRAME_SHIFT 45

//hotkey 'w'
#define KEYCODE_W 0xD

//hotkey 'q'
#define KEYCODE_Q 0xC

//signature status
#define KEY_SIGNATURE_STATUS @"signatureStatus"

//signing auths
#define KEY_SIGNING_AUTHORITIES @"signingAuthorities"

//file belongs to apple?
#define KEY_SIGNING_IS_APPLE @"signedByApple"

//file signed with apple dev id
#define KEY_SIGNING_IS_APPLE_DEV_ID @"signedWithDevID"

//from app store
#define KEY_SIGNING_IS_APP_STORE @"fromAppStore"

//OS version x
#define OS_MAJOR_VERSION_X 10

//OS minor version yosemite
#define OS_MINOR_VERSION_YOSEMITE 10

//OS minor version el capitan
#define OS_MINOR_VERSION_EL_CAPITAN 11

//path to file binary
#define FILE @"/usr/bin/file"

//path to pluginkit binary
#define PLUGIN_KIT @"/usr/bin/pluginkit"

//path to pkgutil
#define PKG_UTIL @"/usr/sbin/pkgutil"

//action to install
// ->also button title
#define ACTION_INSTALL @"Install"

//action to uninstall
// ->also button title
#define ACTION_UNINSTALL @"Uninstall"

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//flag to install
#define ACTION_INSTALL_FLAG 1

//error msg
#define KEY_ERROR_MSG @"errorMsg"

//sub msg
#define KEY_ERROR_SUB_MSG @"errorSubMsg"

//error URL
#define KEY_ERROR_URL @"errorURL"

//flag for error popup
#define KEY_ERROR_SHOULD_EXIT @"shouldExit"

//errors url
#define ERRORS_URL @"https://objective-see.com/errors.html"

//general error URL
#define FATAL_ERROR_URL @"https://objective-see.com/errors.html"

#endif
