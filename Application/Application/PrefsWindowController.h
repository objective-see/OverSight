//
//  file: PrefsWindowController.h
//  project: OverSight (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

#import "UpdateWindowController.h"

/* CONSTS */

//modes view
#define TOOLBAR_MODES 0

//action view
#define TOOLBAR_ACTION 1

//update view
#define TOOLBAR_UPDATE 2

//to select, need string ID
#define TOOLBAR_MODES_ID @"mode"

@interface PrefsWindowController : NSWindowController <NSTextFieldDelegate, NSToolbarDelegate>

/* PROPERTIES */

//preferences
@property(nonatomic, retain)NSDictionary* preferences;

//toolbar
@property (weak) IBOutlet NSToolbar *toolbar;

//rules prefs view
@property (weak) IBOutlet NSView *rulesView;

//modes view
@property (strong) IBOutlet NSView *modesView;

//action view
@property (strong) IBOutlet NSView *actionView;

//path to action
@property (weak) IBOutlet NSTextField *executePath;

//execute args button
@property (weak) IBOutlet NSButton *executeArgsButton;

//update view
@property (weak) IBOutlet NSView *updateView;

//update button
@property (weak) IBOutlet NSButton *updateButton;

//update indicator (spinner)
@property (weak) IBOutlet NSProgressIndicator *updateIndicator;

//update label
@property (weak) IBOutlet NSTextField *updateLabel;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

/* METHODS */

//toolbar button handler
-(IBAction)toolbarButtonHandler:(id)sender;

//button handler for all preference buttons
-(IBAction)togglePreference:(id)sender;

@end
