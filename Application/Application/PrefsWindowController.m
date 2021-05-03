//
//  file: PrefsWindowController.h
//  project: OverSight (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Update.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "PrefsWindowController.h"
#import "UpdateWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation PrefsWindowController

@synthesize toolbar;
@synthesize modesView;
@synthesize rulesView;
@synthesize actionView;
@synthesize updateView;
@synthesize updateWindowController;

//start at login button
#define BUTTON_AUTOSTART_MODE 1

//'no-icon mode' button
#define BUTTON_NO_ICON_MODE 2

//'disable inactive' button
#define BUTTON_DISABLE_INACTIVE_MODE 3

//action
#define BUTTON_EXECUTE_ACTION 4

//args for action
#define BUTTON_EXECUTE_ACTION_ARGS 5

//'update mode' button
#define BUTTON_NO_UPDATE_MODE 6

//init 'general' view
// add it, and make it selected
-(void)awakeFromNib
{
    //set title
    self.window.title = [NSString stringWithFormat:@"%@ v%@", PRODUCT_NAME, getAppVersion()];
    
    //set rules prefs as default
    [self toolbarButtonHandler:nil];
    
    //set rules prefs as default
    [self.toolbar setSelectedItemIdentifier:TOOLBAR_MODES_ID];
    
    return;
}

//toolbar view handler
// toggle view based on user selection
-(IBAction)toolbarButtonHandler:(id)sender
{
    //view
    NSView* view = nil;
    
    //when we've prev added a view
    // remove the prev view cuz adding a new one
    if(nil != sender)
    {
        //remove
        [[[self.window.contentView subviews] lastObject] removeFromSuperview];
    }
    
    //assign view
    switch(((NSToolbarItem*)sender).tag)
    {
        //modes
        case TOOLBAR_MODES:
            
            //set view
            view = self.modesView;
            
            //start at login
            ((NSButton*)[view viewWithTag:BUTTON_AUTOSTART_MODE]).state = [NSUserDefaults.standardUserDefaults boolForKey:PREF_AUTOSTART_MODE];
            
            //no icon
            ((NSButton*)[view viewWithTag:BUTTON_NO_ICON_MODE]).state = [NSUserDefaults.standardUserDefaults boolForKey:PREF_NO_ICON_MODE];
            
            //disable inactive alerts
            ((NSButton*)[view viewWithTag:BUTTON_DISABLE_INACTIVE_MODE]).state = [NSUserDefaults.standardUserDefaults boolForKey:PREF_DISABLE_INACTIVE];
            
            break;
            
        //modes
        case TOOLBAR_ACTION:
            
            //set view
            view = self.actionView;
            
            //action
            ((NSButton*)[view viewWithTag:BUTTON_EXECUTE_ACTION]).state = [NSUserDefaults.standardUserDefaults boolForKey:PREF_EXECUTE_ACTION];
            
            //set 'execute action' path
            if(0 != [NSUserDefaults.standardUserDefaults objectForKey:PREF_EXECUTE_PATH])
            {
                //set
                self.executePath.stringValue = [NSUserDefaults.standardUserDefaults objectForKey:PREF_EXECUTE_PATH];
            }
               
            //set state of 'execute action' to match
            self.executePath.enabled = [NSUserDefaults.standardUserDefaults boolForKey:PREF_EXECUTE_ACTION];
            
            //set action + args
            ((NSButton*)[view viewWithTag:BUTTON_EXECUTE_ACTION_ARGS]).state = [NSUserDefaults.standardUserDefaults boolForKey:PREF_EXECUTE_ACTION_ARGS];
            
            //set state of 'execute action' to match
            self.executeArgsButton.enabled = [NSUserDefaults.standardUserDefaults boolForKey:PREF_EXECUTE_ACTION];
        
            break;
            
            
        //update
        case TOOLBAR_UPDATE:
            
            //set view
            view = self.updateView;
    
            //set 'update' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_UPDATE_MODE]).state = [NSUserDefaults.standardUserDefaults boolForKey:PREF_NO_UPDATE_MODE];
        
            break;
            
        default:
            
            //bail
            goto bail;
    }
    
    //set frame rect
    view.frame = CGRectMake(0, 75, self.window.contentView.frame.size.width, self.window.contentView.frame.size.height-75);
    
    //add to window
    [self.window.contentView addSubview:view];
    
bail:
    
    return;
}

//automatically called when 'enter' is hit
// save values that were entered in text field
-(void)controlTextDidEndEditing:(NSNotification *)notification
{
    //execute path?
    if([notification object] != self.executePath)
    {
        //bail
        goto bail;
    }
    
    //save & sync
    [NSUserDefaults.standardUserDefaults setObject:self.executePath.stringValue forKey:PREF_EXECUTE_PATH];
    [NSUserDefaults.standardUserDefaults synchronize];
        
bail:

    return;
}

//invoked when user toggles button
// update preferences for that button
-(IBAction)togglePreference:(id)sender
{
    //preferences
    NSMutableDictionary* updatedPreferences = nil;
    
    //button state
    BOOL state = NO;
    
    //init
    updatedPreferences = [NSMutableDictionary dictionary];
    
    //get button state
    state = ((NSButton*)sender).state;
    
    //set appropriate preference
    switch(((NSButton*)sender).tag)
    {
        //autostart
        case BUTTON_AUTOSTART_MODE:
        {
            //toggle login item
            toggleLoginItem([NSURL fileURLWithPath:NSBundle.mainBundle.bundlePath], state);
            
            //set
            [NSUserDefaults.standardUserDefaults setBool:state forKey:PREF_PASSIVE_MODE];
            
            break;
        }
        
        //no icon mode
        case BUTTON_NO_ICON_MODE:
        {
            //toggle
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) toggleIcon:!state];
            
            //set
            [NSUserDefaults.standardUserDefaults setBool:state forKey:PREF_NO_ICON_MODE];
            
            break;
        }
        
        //disable inactive mode
        case BUTTON_DISABLE_INACTIVE_MODE:
        {
            //set
            [NSUserDefaults.standardUserDefaults setBool:state forKey:PREF_DISABLE_INACTIVE];
            break;
        }
            
        //execute action
        // also toggle state of path
        case BUTTON_EXECUTE_ACTION:
        {
            //set
            [NSUserDefaults.standardUserDefaults setBool:state forKey:PREF_EXECUTE_ACTION];
            
            //set path field state to match
            self.executePath.enabled = state;
            
            //set path field state to match
            self.executeArgsButton.enabled = state;
            
            break;
        }
            
        //execute action
        // also toggle state of path
        case BUTTON_EXECUTE_ACTION_ARGS:
        {
            //set
            [NSUserDefaults.standardUserDefaults setBool:state forKey:PREF_EXECUTE_ACTION_ARGS];
            break;
        }
            
        //no update mode
        case BUTTON_NO_UPDATE_MODE:
        {
            //set
            [NSUserDefaults.standardUserDefaults setBool:state forKey:PREF_NO_UPDATE_MODE];
            break;
        }
            
        default:
            break;
    }
    
    //sync
    [NSUserDefaults.standardUserDefaults synchronize];
    
    return;
}

//'view rules' button handler
// call helper method to show rule's window
-(IBAction)viewRules:(id)sender
{
    //call into app delegate to show app rules
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) showRules:nil];
    
    return;
}

//'check for update' button handler
-(IBAction)check4Update:(id)sender
{
    //update obj
    Update* update = nil;
    
    //disable button
    self.updateButton.enabled = NO;
    
    //reset
    self.updateLabel.stringValue = @"";
    
    //show/start spinner
    [self.updateIndicator startAnimation:self];
    
    //init update obj
    update = [[Update alloc] init];
    
    //check for update
    // 'updateResponse newVersion:' method will be called when check is done
    [update checkForUpdate:^(NSUInteger result, NSString* newVersion) {
        
        //process response
        [self updateResponse:result newVersion:newVersion];
        
    }];
    
    return;
}

//process update response
// error, no update, update/new version
-(void)updateResponse:(NSInteger)result newVersion:(NSString*)newVersion
{
    //re-enable button
    self.updateButton.enabled = YES;
    
    //stop/hide spinner
    [self.updateIndicator stopAnimation:self];
    
    switch(result)
    {
        //error
        case -1:
            
            //set label
            self.updateLabel.stringValue = @"error: update check failed";
            
            break;
            
        //no updates
        case 0:
            
            //dbg msg
            os_log_debug(logHandle, "no updates available");
            
            //set label
            self.updateLabel.stringValue = [NSString stringWithFormat:@"Installed version (%@),\r\nis the latest.", getAppVersion()];
            
            break;
         
            
        //new version
        case 1:
            
            //dbg msg
            os_log_debug(logHandle, "a new version (%@) is available", newVersion);
            
            //alloc update window
            updateWindowController = [[UpdateWindowController alloc] initWithWindowNibName:@"UpdateWindow"];
            
            //configure
            [self.updateWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available!", newVersion] buttonTitle:@"Update"];
            
            //center window
            [[self.updateWindowController window] center];
            
            //show it
            [self.updateWindowController showWindow:self];
            
            //invoke function in background that will make window modal
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                //make modal
                makeModal(self.updateWindowController);
                
            });
            
            break;
    }
    
    
    return;
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
