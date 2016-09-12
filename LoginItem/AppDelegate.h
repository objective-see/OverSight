//
//  AppDelegate.h
//  Test Application Helper
//
//  Created by Patrick Wardle on 9/10/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "AVMonitor.h"
#import "EventMonitor.h"
#import "StatusBarMenu.h"

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

/* PROPERTIES */

//status bar menu
@property(nonatomic, retain)StatusBarMenu* statusBarMenuController;

//(camera event) monitor class
@property(nonatomic, retain)EventMonitor* monitor;

@property(nonatomic, retain)AVMonitor* avMonitor;

@end

