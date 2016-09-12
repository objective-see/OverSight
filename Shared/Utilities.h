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

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion();

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments);

//get OS's major or minor version
SInt32 getVersion(OSType selector);

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//given a directory and a filter predicate
// ->return all matches
NSArray* directoryContents(NSString* directory, NSString* predicate);

//hash (sha1/md5) a file
NSDictionary* hashFile(NSString* filePath);

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion();

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments);

//get process's path
NSString* getProcessPath(pid_t pid);


#endif
