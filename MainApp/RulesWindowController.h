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
@property(nonatomic, retain)NSMutableArray* items;

//table view
@property (weak) IBOutlet NSTableView *tableView;

/* METHODS */

//delete a rule
- (IBAction)deleteRule:(id)sender;

@end
