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


/* METHODS */

//register handler for hot keys
-(void)registerKeypressHandler;

//helper function for keypresses
// ->for now, only handle cmd+q, to quit
-(NSEvent*)handleKeypress:(NSEvent*)event;

//toggle/set preferences
-(IBAction)togglePreference:(NSButton *)sender;

//'about' button handler
-(IBAction)about:(id)sender;

//'check for update' (now) button handler
-(IBAction)check4Update:(id)sender;

//check for an update
-(void)isThereAnUpdate;

//start the login item
-(IBAction)startLoginItem:(id)sender;


@end

