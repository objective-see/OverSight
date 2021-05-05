//
//  file: RulesWindowController.m
//  project: OverSight (main app)
//  description: window controller for 'rules' table
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "RuleRow.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "RulesWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation RulesWindowController

@synthesize rules;

//alloc/init
// get rules and listen for new ones
-(void)windowDidLoad
{
    //setup observer for new rules
    self.rulesObserver = [[NSNotificationCenter defaultCenter] addObserverForName:RULES_CHANGED object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        //get new rules
        [self loadRules];
    }];
    
    return;
}

//configure (UI)
-(void)configure
{
    //load rules
    [self loadRules];
    
    //center window
    [self.window center];
    
    //show window
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];

    return;
}


//get rules from daemon
// then, re-load rules table
-(void)loadRules
{
    //dbg msg
    os_log_debug(logHandle, "loading rules...");
    
    //in background get rules
    // ...then load rule table table
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //get rules
        self.rules = [[NSUserDefaults.standardUserDefaults objectForKey:PREFS_ALLOWED_ITEMS] mutableCopy];
        
        //dbg msg
        os_log_debug(logHandle, "loaded %lu allowed items", (unsigned long)self.rules.count);
        
        //remove any non-existant (old) items
        for(NSInteger i = self.rules.count-1; i >= 0; i--)
        {
            //item path
            NSString* itemPath = nil;
            
            //extract
            itemPath = self.rules[i][EVENT_PROCESS_PATH];
            
            //item no longer exists?
            if(YES != [NSFileManager.defaultManager fileExistsAtPath:itemPath])
            {
                //dbg msg
                os_log_debug(logHandle, "removing allowed item %{public}@, as it no longer exists", itemPath);
                
                //remove
                [self.rules removeObjectAtIndex:i];
            }
        }
        
        //save & sync cleaned up list
        [NSUserDefaults.standardUserDefaults setObject:self.rules forKey:PREFS_ALLOWED_ITEMS];
        [NSUserDefaults.standardUserDefaults synchronize];

        //sort
        // case insenstive on name
        self.rules = [[self.rules sortedArrayUsingComparator:^NSComparisonResult(NSDictionary* a, NSDictionary* b)
        {
            return [getProcessName(a[EVENT_PROCESS_PATH]) caseInsensitiveCompare: getProcessName(b[EVENT_PROCESS_PATH])];
                           
        }] mutableCopy];
           
        //show rules in UI
        // ...gotta do this on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //reload table
            [self.tableView reloadData];
          
            //select first row
            [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
            
            //set overlay vibility
            self.overlay.hidden = !(0 == self.rules.count);
             
        });

    });
    
    return;
}

//delete an allowed item
-(IBAction)deleteRule:(id)sender
{
    //index of row
    // either clicked or selected row
    NSInteger row = 0;
    
    //allowed items
    NSMutableArray* allowedItems = nil;
    
    //item to delete
    NSDictionary* item = nil;
    
    //dbg msg
    os_log_debug(logHandle, "deleting allowed item");
    
    //get selected row
    row = [self.tableView rowForView:sender];
    if(-1 == row) goto bail;
    
    //get item
    item = self.rules[row];
    
    //dbg msg
    os_log_debug(logHandle, "allowed item: %{public}@ (device: %@)", item[EVENT_PROCESS_PATH], item[EVENT_DEVICE]);
    
    //(re)load items
    allowedItems = [[NSUserDefaults.standardUserDefaults objectForKey:PREFS_ALLOWED_ITEMS] mutableCopy];
    
    //find/remove item
    for (NSInteger i = allowedItems.count - 1; i >= 0; i--)
    {
        if( (item[EVENT_DEVICE] != allowedItems[i][EVENT_DEVICE]) ||
            (item[EVENT_PROCESS_PATH] != allowedItems[i][EVENT_PROCESS_PATH]) )
        {
            //no match
            continue;
        }
        
        //remove
        [allowedItems removeObjectAtIndex:i];
    }
    
    //save & sync
    [NSUserDefaults.standardUserDefaults setObject:allowedItems forKey:PREFS_ALLOWED_ITEMS];
    [NSUserDefaults.standardUserDefaults synchronize];
    
    //reload rules
    [self loadRules];

bail:
    
    return;
}

#pragma mark -
#pragma mark table delegate methods

//number of rows
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    //row's count
    return self.rules.count;
}

//cell for table column
-(NSView*)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    //cell
    NSTableCellView *tableCell = nil;
    
    //item
    NSDictionary* allowedItem = nil;
    
    //process path
    NSString* processPath = nil;
    
    //grab item
    allowedItem = self.rules[row];
    
    //column: 'process'
    // set process icon, name and path
    if(tableColumn == tableView.tableColumns[0])
    {
        //init table cell
        tableCell = [tableView makeViewWithIdentifier:@"processCell" owner:self];
        if(nil == tableCell)
        {
            //bail
            goto bail;
        }
        
        //extract path
        processPath = allowedItem[EVENT_PROCESS_PATH];
        
        //set icon
        tableCell.imageView.image = getIconForProcess(processPath);
        
        //set process name
        tableCell.textField.stringValue = getProcessName(processPath);
        
        //set sub text (path)
        ((NSTextField*)[tableCell viewWithTag:TABLE_ROW_SUB_TEXT_FILE]).stringValue = processPath;
        
        //set text color to gray
        ((NSTextField*)[tableCell viewWithTag:TABLE_ROW_SUB_TEXT_FILE]).textColor = [NSColor secondaryLabelColor];
    }
    
    //column: 'rule'
    // set icon and rule action
    else
    {
        //init table cell
        tableCell = [tableView makeViewWithIdentifier:@"ruleCell" owner:self];
        if(nil == tableCell)
        {
            //bail
            goto bail;
        }
        
        tableCell.textField.stringValue = (Device_Camera == [allowedItem[EVENT_DEVICE] intValue]) ? @"camera" : @"microphone";
    }
    
bail:
    
    return tableCell;
}

//row for view
-(NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    //row view
    RuleRow* rowView = nil;
    
    //row ID
    static NSString* const kRowIdentifier = @"RowView";
    
    //try grab existing row view
    rowView = [tableView makeViewWithIdentifier:kRowIdentifier owner:self];
    
    //make new if needed
    if(nil == rowView)
    {
        //create new
        // ->size doesn't matter
        rowView = [[RuleRow alloc] initWithFrame:NSZeroRect];
        
        //set row ID
        rowView.identifier = kRowIdentifier;
    }
    
    return rowView;
}

//on window close
// set activation policy
-(void)windowWillClose:(NSNotification *)notification
{
     //wait a bit, then set activation policy
     dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
     ^{
         //on main thread
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
             
             //set activation policy
             [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
             
         });
     });
    
    return;
}

@end
