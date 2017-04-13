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
#import "RulesWindowController.h"
#import "3rdParty/HyperlinkTextField.h"


@interface AppDelegate : NSObject <NSApplicationDelegate>

/* PROPERTIES */

//about button
@property (weak) IBOutlet NSButton *about;

//log activity button
@property (weak) IBOutlet NSButton *logActivity;

//label to show button
@property (weak) IBOutlet HyperlinkTextField *viewLogLabel;

//check for updates automatically button
@property (weak) IBOutlet NSButton *check4Updates;

//start at login button
@property (weak) IBOutlet NSButton *startAtLogin;

//run in headless mode button
@property (weak) IBOutlet NSButton *runHeadless;

//disable 'inactive' alerts
@property (weak) IBOutlet NSButton *disableInactive;

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

//rules
@property(nonatomic, retain)RulesWindowController* rulesWindowController;

//overlay view
@property (weak) IBOutlet NSView *overlay;

//status message
@property (weak) IBOutlet NSTextField *statusMessage;

//progress indicator
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

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

//'manage rules' button handler
-(IBAction)manageRules:(id)sender;

//(re)start the login item
-(void)startLoginItem:(BOOL)shouldRestart args:(NSArray*)args;

@end

