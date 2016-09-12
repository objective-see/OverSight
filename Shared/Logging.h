//
//  Logging.h
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//
#import <syslog.h>
#import <Foundation/Foundation.h>

//log a msg to syslog
// ->also disk, if error
void logMsg(int level, NSString* msg);

