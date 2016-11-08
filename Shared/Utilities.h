//
//  Utilities.h
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef WYS_Utilities_h
#define WYS_Utilities_h

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

/* FUNCTIONS */

//get OS version
NSDictionary* getOSVersion();

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion();

//set dir's|file's group/owner
BOOL setFileOwner(NSString* path, NSNumber* groupID, NSNumber* ownerID, BOOL recursive);

//set permissions for file
BOOL setFilePermissions(NSString* file, int permissions, BOOL recursive);

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments);

//get OS's major or minor version
SInt32 getVersion(OSType selector);

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion();

//query interwebz to get latest version
NSString* getLatestVersion();

//determine if there is a new version
// -1, YES or NO
NSInteger isNewVersion(NSMutableString* versionString);

//get process's path
NSString* getProcessPath(pid_t pid);

//given a pid
// ->get the name of the process
NSString* getProcessName(pid_t pid);

//given a process name
// ->get the (first) instance of that process
pid_t getProcessID(NSString* processName, uid_t userID);

//wait until a window is non nil
// ->then make it modal
void makeModal(NSWindowController* windowController);

//toggle login item
// ->either add (install) or remove (uninstall)
BOOL toggleLoginItem(NSURL* loginItem, int toggleFlag);

#endif
