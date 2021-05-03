//
//  file: RulesWindowController.h
//  project: OverSight (main app)
//  description: window controller for 'rules' table (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

/* CONSTS */

//id (tag) for detailed text in category table
#define TABLE_ROW_NAME_TAG 100

//id (tag) for detailed text (file)
#define TABLE_ROW_SUB_TEXT_FILE 101

//id (tag) for detailed text (item)
#define TABLE_ROW_SUB_TEXT_ITEM 102

//id (tag) for delete button
#define TABLE_ROW_DELETE_TAG 110

//menu item for block
#define MENU_ITEM_BLOCK 0

//menu item for allow
#define MENU_ITEM_ALLOW 1

//menu item for delete
#define MENU_ITEM_DELETE 2

/* INTERFACE */

@interface RulesWindowController : NSWindowController <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>
{
    
}

/* PROPERTIES */

//overlay
@property (weak) IBOutlet NSView *overlay;

//observer for rules changed
@property(nonatomic, retain)id rulesObserver;

//table items
// all of the rules
@property(nonatomic, retain)NSMutableArray* rules;


//top level view
@property (weak) IBOutlet NSView *view;

//table view
@property (weak) IBOutlet NSTableView *tableView;

//panel for 'add rule'
@property (weak) IBOutlet NSView *addRulePanel;

/* METHODS */

//configure (UI)
-(void)configure;

//get rules from daemon
// then, re-load rules table
-(void)loadRules;

//delete a rule
-(IBAction)deleteRule:(id)sender;

@end
