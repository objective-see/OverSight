//
//  Consts.h
//  OverSight
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef OS_Consts_h
#define OS_Consts_h

//success
#define STATUS_SUCCESS 0

//apps folder
#define APPS_FOLDER @"/Applications"

//app name
#define APP_NAME @"OverSight.app"

//app helper name
#define APP_HELPER_NAME @"OverSight Helper"

//product url
#define PRODUCT_URL @"https://objective-see.com/products/oversight.html"

//product version url
//TODO: test final/with page
#define PRODUCT_VERSION_URL @"https://objective-see.com/products/versions/oversight.json"

//frame shift
// ->for status msg to avoid activity indicator
#define FRAME_SHIFT 45

//OS version x
#define OS_MAJOR_VERSION_X 10

//OS minor version yosemite
#define OS_MINOR_VERSION_YOSEMITE 10

//OS minor version el capitan
#define OS_MINOR_VERSION_EL_CAPITAN 11

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

//path to preferences
#define APP_PREFERENCES @"~/Library/Preferences/com.objective-see.OverSight.plist"

//log activity button
#define PREF_LOG_ACTIVITY @"logActivity"

//automatically check for updates button
#define PREF_CHECK_4_UPDATES @"check4Updates"

//keycode for 'q'
#define KEYCODE_Q 0x0C

//path to pkill
#define PKILL @"/usr/bin/pkill"

#endif
