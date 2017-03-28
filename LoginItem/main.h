//
//  main.h
//  OverSight
//
//  Created by Patrick Wardle on 9/10/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef main_h
#define main_h

#import "Consts.h"
#import "Logging.h"
#import <Cocoa/Cocoa.h>

/* FUNCTION DEFINITIONS */

//send XPC message to remove process from whitelist file
void unWhiteList(NSString* process);

#endif /* main_h */
