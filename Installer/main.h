//
//  main.h
//  Installer
//
//  Created by Patrick Wardle on 9/14/16.
//  Copyright © 2016 Objective-See. All rights reserved.
//

#ifndef main_h
#define main_h

#import "Consts.h"
#import "Logging.h"
#import "Configure.h"

#import <syslog.h>
#import <Cocoa/Cocoa.h>

/* FUNCTION DECLARATIONS */

//spawn self as root
BOOL spawnAsRoot(const char* path2Self);

#endif /* main_h */