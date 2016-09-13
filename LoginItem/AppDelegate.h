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
#import "InfoWindowController.h"

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

/* PROPERTIES */

//av monitor class
@property(nonatomic, retain)AVMonitor* avMonitor;

//status bar menu
@property(nonatomic, retain)StatusBarMenu* statusBarMenuController;

//info window
@property(nonatomic, retain)InfoWindowController* infoWindowController;

@end

