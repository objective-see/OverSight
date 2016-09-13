//
//  AppDelegate.h
//  Test Application
//
//  Created by Patrick Wardle on 9/10/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "InfoWindowController.h"
#import "AboutWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

/* PROPERTIES */

//about button
@property (weak) IBOutlet NSButton *about;

//log activity button
@property (weak) IBOutlet NSButton *logActivity;

//check for updates automatically button
@property (weak) IBOutlet NSButton *check4Updates;

//check for updates now button
@property (weak) IBOutlet NSButton *check4UpdatesNow;

//check for updates spinner
@property (weak) IBOutlet NSProgressIndicator *spinner;

//version label
@property (weak) IBOutlet NSTextField *versionLabel;

//info window
@property(nonatomic, retain)InfoWindowController* infoWindowController;

//about window controller
@property(nonatomic, retain)AboutWindowController* aboutWindowController;

@end

