//
//  RulesWindowController.h
//  OverSight
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RulesWindowController : NSWindowController <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate>

/* PROPERTIES */

//table items
@property(nonatomic, retain)NSMutableArray* items;

//top level view
@property (weak) IBOutlet NSView *view;

//table view
@property (weak) IBOutlet NSTableView *tableView;

//overlay
@property (strong) IBOutlet NSView *overlay;

//activity indicator
@property (weak) IBOutlet NSProgressIndicator *spinner;

//status message
@property (weak) IBOutlet NSTextField *message;

/* METHODS */

//delete a rule
-(IBAction)deleteRule:(id)sender;

@end
