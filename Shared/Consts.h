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
#define APP_HELPER @"OverSight Helper"

//app helper XPC
#define APP_HELPER_XPC @"OverSight XPC"

//product url
#define PRODUCT_URL @"https://objective-see.com/products/oversight.html"

//product version url
#define PRODUCT_VERSION_URL @"https://objective-see.com/products.json"

//patreon url
#define PATREON_URL @"https://www.patreon.com/objective_see"

//OS version x
#define OS_MAJOR_VERSION_X 10

//OS minor version yosemite
#define OS_MINOR_VERSION_YOSEMITE 10

//OS minor version el capitan
#define OS_MINOR_VERSION_EL_CAPITAN 11

//install flag
#define CMD_INSTALL "-install"

//uninstall flag
#define CMD_UNINSTALL "-uninstall"

//action to install
// ->also button title
#define ACTION_INSTALL @"Install"

//action to uninstall
// ->also button title
#define ACTION_UNINSTALL @"Uninstall"

//button title
// ->close
#define ACTION_CLOSE @"Close"

//button title
// ->next
#define ACTION_NEXT @"Next »"

//button title
// ->no
#define ACTION_NO @"No"

//button title
// ->yes
#define ACTION_YES @"Yes!"

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//flag to install
#define ACTION_INSTALL_FLAG 1

//flag for partial uninstall (leave whitelist)
#define UNINSTALL_PARIAL 0

//flag for full uninstall
#define UNINSTALL_FULL 1

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

//run in headless mode
#define PREF_RUN_HEADLESS @"runHeadless"

//start at login
#define PREF_START_AT_LOGIN @"startAtLogin"

//disable 'inactive' alerts
#define PREF_DISABLE_INACTIVE @"disableInactive"

//keycode for 'q'
#define KEYCODE_Q 0x0C

//path to pkill
#define PKILL @"/usr/bin/pkill"

//path to xattr
#define XATTR @"/usr/bin/xattr"

//path to sudo
#define SUDO @"/usr/bin/sudo"

//path to facetime
#define FACE_TIME @"/Applications/FaceTime.app/Contents/MacOS/FaceTime"

//app support directory
#define APP_SUPPORT_DIRECTORY @"~/Library/Application Support/Objective-See/OverSight"

//whitelist
#define FILE_WHITELIST @"whitelist.plist"

//event keys
#define EVENT_DEVICE @"device"
#define EVENT_TIMESTAMP @"timeStamp"
#define EVENT_DEVICE_STATUS @"status"
#define EVENT_PROCESS_ID @"processID"
#define EVENT_ALERT_TYPE @"alertType"
#define EVENT_ALERT_CLOSED @"eventClose"
#define EVENT_PROCESS_NAME @"processName"
#define EVENT_PROCESS_PATH @"processPath"

//unknown process
#define PROCESS_UNKNOWN @"<unknown>"

//went inactive
#define ALERT_INACTIVE @0x0

//went active
#define ALERT_ACTIVATE @0x1

//source audio
#define SOURCE_AUDIO @0x1

//source video
#define SOURCE_VIDEO @0x2

//always allow button
#define BUTTON_ALWAYS_ALLOW 100

//no/close button
#define BUTTON_NO 101

//id (tag) for detailed text in rules table
#define TABLE_ROW_SUB_TEXT_TAG 101

//support us button tag
#define BUTTON_SUPPORT_US 100

//more info button tag
#define BUTTON_MORE_INFO 101


#endif
