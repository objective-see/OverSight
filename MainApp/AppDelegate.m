//
//  AppDelegate.m
//  Test Application
//
//  Created by Patrick Wardle on 9/10/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

@synthesize infoWindowController;
@synthesize aboutWindowController;

//center window
// ->also make front, init title bar, etc
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //set title
    self.window.title = [NSString stringWithFormat:@"OverSight Preferences (v. %@)", getAppVersion()];
    
    return;
}

//app interface
// ->init user interface
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //set 'log activity' button state
    self.logActivity.state = [[NSUserDefaults standardUserDefaults] boolForKey:PREF_LOG_ACTIVITY];
    
    //set 'automatically check for updates' button state
    self.check4Updates.state = [[NSUserDefaults standardUserDefaults] boolForKey:PREF_CHECK_4_UPDATES];
    
    //register for hotkey presses
    // ->for now, just cmd+q to quit app
    [self registerKeypressHandler];
    
    return;
}

//automatically close when user closes window
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

//register handler for hot keys
-(void)registerKeypressHandler
{
    //event handler
    NSEvent* (^keypressHandler)(NSEvent *) = nil;
    
    //init handler block
    // ->just call helper function
    keypressHandler = ^NSEvent * (NSEvent * theEvent){
        
        //invoke helper
        return [self handleKeypress:theEvent];
    };
    
    //register for key-down events
    [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:keypressHandler];
    
    return;
}


//helper function for keypresses
// ->for now, only handle cmd+q, to quit
-(NSEvent*)handleKeypress:(NSEvent*)event
{
    //flag indicating event was handled
    BOOL wasHandled = NO;
    
    //only care about 'cmd' + something
    if(NSCommandKeyMask != (event.modifierFlags & NSCommandKeyMask))
    {
        //bail
        goto bail;
    }
    
    //handle key-code
    // command+q: quite
    switch ([event keyCode])
    {
        //'q' (quit)
        case KEYCODE_Q:
            
            //bye!
            [[NSApplication sharedApplication] terminate:nil];
            
            //set flag
            wasHandled = YES;
            
            break;
            
        default:
            
            break;
    }
    
//bail
bail:
    
    //nil out event if it was handled
    if(YES == wasHandled)
    {
        //nil
        event = nil;
    }
    
    return event;

}

//toggle/set preferences
-(IBAction)togglePreference:(NSButton *)sender
{
    //set 'log activity' button
    if(sender == self.logActivity)
    {
        //set
        [[NSUserDefaults standardUserDefaults] setBool:[sender state] forKey:PREF_LOG_ACTIVITY];
    }
    
    //set 'automatically check for updates'
    else if (sender == self.check4Updates)
    {
        //set
        [[NSUserDefaults standardUserDefaults] setBool:[sender state] forKey:PREF_CHECK_4_UPDATES];
    }
    
    //save em
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    return;
}

//'about' button handler
-(IBAction)about:(id)sender
{
    //alloc/init settings window
    if(nil == self.aboutWindowController)
    {
        //alloc/init
        aboutWindowController = [[AboutWindowController alloc] initWithWindowNibName:@"AboutWindow"];
    }
    
    //center window
    [[self.aboutWindowController window] center];
    
    //show it
    [self.aboutWindowController showWindow:self];
    
    //invoke function in background that will make window modal
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //make modal
        makeModal(self.aboutWindowController);
        
    });
    
    return;
    
}

//'check for update' (now) button handler
-(IBAction)check4Update:(id)sender
{
    //disable button
    self.check4UpdatesNow.enabled = NO;
    
    //hide version msg
    self.versionLabel.hidden = YES;
    
    //show spinner
    [self.spinner startAnimation:self];
    
    //check for update
    [self isThereAndUpdate];
    
    return;
}

//check for an update
-(void)isThereAndUpdate
{
    //version string
    NSMutableString* versionString = nil;
    
    //alloc string
    versionString = [NSMutableString string];
    
    //check if available version is newer
    // ->show update window
    if(YES == isNewVersion(versionString))
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", versionString]);
        
        //alloc/init about window
        infoWindowController = [[InfoWindowController alloc] initWithWindowNibName:@"InfoWindow"];
        
        //configure
        [self.infoWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available!", versionString] buttonTitle:@"update"];
        
        //center window
        [[self.infoWindowController window] center];
        
        //show it
        [self.infoWindowController showWindow:self];
        
        //invoke function in background that will make window modal
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //make modal
            makeModal(self.infoWindowController);
            
        });
        
        //stop/hide spinner
        [self.spinner stopAnimation:self];
        
        //re-enable button
        self.check4UpdatesNow.enabled = YES;
    }
    
    //no new version
    // ->just (debug) log msg
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"no updates available");
        
        //stop/hide spinner
        [self.spinner stopAnimation:self];
        
        //re-enable button
        self.check4UpdatesNow.enabled = YES;
        
        //show now new version message
        self.versionLabel.hidden = NO;
    }
    
    return;
}


@end
