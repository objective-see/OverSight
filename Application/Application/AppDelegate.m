//
//  file: AppDelegate.m
//  project: OverSight (login item)
//  description: app delegate for login item
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import UserNotifications;

#import "consts.h"
#import "Update.h"
#import "utilities.h"
#import "LogMonitor.h"
#import "AppDelegate.h"


/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation AppDelegate

@synthesize avMonitor;
@synthesize aboutWindowController;
@synthesize prefsWindowController;
@synthesize rulesWindowController;
@synthesize updateWindowController;
@synthesize statusBarItemController;

//app's main interface
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    //parent
    NSDictionary* parent = nil;
    
    //flag
    BOOL autoLaunched = NO;
    
    //init
    self.avMonitor = [[AVMonitor alloc] init];
    
    //get real parent
    parent = getRealParent(getpid());
    
    //dbg msg(s)
    os_log_debug(logHandle, "(real) parent: %{public}@", parent);
    
    //set auto launched flag (i.e. login item)
    autoLaunched = [parent[@"CFBundleIdentifier"] isEqualToString:@"com.apple.loginwindow"];
    
    //when user (manually) runs app
    // show the app's preferences window
    if( (YES != autoLaunched) &&
        (YES != [NSProcessInfo.processInfo.arguments containsObject:INITIAL_LAUNCH]))
    {
        //show preferences
        [self showPreferences:nil];
    }
    
    //show status bar item/icon?
    if(YES != [NSUserDefaults.standardUserDefaults boolForKey:PREF_NO_ICON_MODE])
    {
        //alloc/load nib
        statusBarItemController = [[StatusBarItem alloc] init:self.statusMenu];
    }
    
    //enabled?
    // kick off device monitoring
    if(YES != [NSUserDefaults.standardUserDefaults boolForKey:PREF_IS_DISABLED])
    {
        //start
        [self.avMonitor start];
    }
    //disabled
    else
    {
        //dbg msg
        os_log_debug(logHandle, "is disabled, didn't start monitor");
    }
    
    //automatically check for updates?
    if(YES != [NSUserDefaults.standardUserDefaults boolForKey:PREF_NO_UPDATE_MODE])
    {
        //after a 30 seconds
        // check for updates in background
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            //dbg msg
            os_log_debug(logHandle, "checking for update");
           
            //check
            [self check4Update];
       });
    }

    //can show notifications?
    [self checkNotificationState];
    
bail:
        
    return;
}

//can show notifications?
-(void)checkNotificationState
{
    //notification style
    __block NSString* style = nil;
    
    //request authorization to allow notifications
    // can always invoke this, as if user has already approved, this won't trigger any (secondary) prompt
    [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:(UNAuthorizationOptionAlert) completionHandler:^(BOOL granted, NSError * _Nullable error)
    {
        //dbg msg
        os_log_debug(logHandle, "permission to display notifications granted? %d (error: %{public}@)", granted, error);
    
        //not granted/error
        if( (nil != error) ||
            (YES != granted) )
        {
            //on main thread
            // show alert / open system preferences
            dispatch_async(dispatch_get_main_queue(), ^{
                
                //show alert
                showAlert(NSLocalizedString(@"ERROR: OverSight is not authorized to display notifications.", @"ERROR: OverSight is not authorized to display notifications."), NSLocalizedString(@"Please authorize (style: \"Alerts\") via the Notifications pane in System Preferences.", @"Please authorize (style: \"Alerts\") via the Notifications pane in System Preferences."), NSLocalizedString(@"Open System Preferences...", @"Open System Preferences..."));
                
                //open `System Preferences` notifications pane
                [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.notifications?com.objective-see.oversight"]];
                
            });
        }
        
        //granted?
        // on first run, ask nicely to have "alert" style set
        else if( (YES == granted) &&
                 (YES == [NSProcessInfo.processInfo.arguments containsObject:INITIAL_LAUNCH]) )
        {
            //get settings
            [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings)
             {
                //enabled / alert style?
                if( (UNAlertStyleAlert != settings.alertStyle) ||
                    (UNNotificationSettingEnabled != settings.alertSetting) )
                {
                    //set style: none
                    if(UNAlertStyleNone == settings.alertStyle)
                    {
                        //set
                        style = @"\"None\"";
                    }
                    //set style: banners
                    else if(UNAlertStyleBanner == settings.alertStyle)
                    {
                        //set
                        style = @"\"Banners\"";
                    }
                     
                    //on main thread
                    // show alert / open system preferences
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        //show alert
                        showAlert([NSString stringWithFormat:NSLocalizedString(@"OverSight notification mode set to %@.", @"OverSight notification mode set to %@."), style], NSLocalizedString(@"Please change to \"Alerts\" via the Notifications pane in System Preferences.", @"Please change to \"Alerts\" via the Notifications pane in System Preferences."), NSLocalizedString(@"Open System Preferences...",@"Open System Preferences..."));
                        
                        //open `System Preferences` notifications pane
                        [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.notifications?com.objective-see.oversight"]];
                        
                    });
                }
            }];
        }
    }];

    return;
}

//handle user double-clicks
// app is (likely) already running as login item, so show (or) activate window
-(BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)hasVisibleWindows
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked from (hasVisibleWindows: %d)", __PRETTY_FUNCTION__, hasVisibleWindows);
 
    //already shown?
    // nothing to do, bail
    if(YES == hasVisibleWindows)
    {
        goto bail;
    }
    
    //no notifications
    // show preferences window
    if(nil == avMonitor.lastNotificationDefaultAction)
    {
        //show prefs
        [self showPreferences:nil];
    }
    //had notifications
    // if more than one second, show preferences window
    else if(fabs([avMonitor.lastNotificationDefaultAction timeIntervalSinceNow]) > 1)
    {
        //show prefs
        [self showPreferences:nil];
    }
           
bail:
    
    return NO;
}

//'rules' menu item handler
// alloc and show rules window
-(IBAction)showRules:(id)sender
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //alloc rules window controller
    if(nil == self.rulesWindowController)
    {
        //dbg msg
        os_log_debug(logHandle, "allocating rules window controller...");
        
        //alloc
        rulesWindowController = [[RulesWindowController alloc] initWithWindowNibName:@"Rules"];
    }
    
    //configure (UI)
    [self.rulesWindowController configure];
    
    //make active
    [self makeActive:self.rulesWindowController];
    
    return;
}

//'preferences' menu item handler
// alloc and show preferences window
-(IBAction)showPreferences:(id)sender
{
    //alloc prefs window controller
    if(nil == self.prefsWindowController)
    {
        //alloc
        prefsWindowController = [[PrefsWindowController alloc] initWithWindowNibName:@"Preferences"];
    }
    
    //make active
    [self makeActive:self.prefsWindowController];
    
    return;
}

//'about' menu item handler
// alloc/show the about window
-(IBAction)showAbout:(id)sender
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
    
    return;
}

//close window handler
// close rules || pref window
-(IBAction)closeWindow:(id)sender {
    
    //key window
    NSWindow *keyWindow = nil;
    
    //get key window
    keyWindow = [[NSApplication sharedApplication] keyWindow];
    
    //dbg msg
    os_log_debug(logHandle, "close window request (key window: %@)", keyWindow);

    //close
    // but only for rules/pref/about window
    if( (keyWindow != self.aboutWindowController.window) &&
        (keyWindow != self.prefsWindowController.window) &&
        (keyWindow != self.rulesWindowController.window) )
    {
        //dbg msg
        os_log_debug(logHandle, "key window is not rules or pref window, so ignoring...");
        
        //ignore
        goto bail;
    }
    
    //close
    [keyWindow close];
    
    //set activation policy
    [self setActivationPolicy];
    
bail:
    
    return;
}

//make a window control/window front/active
-(void)makeActive:(NSWindowController*)windowController
{
    //make foreground
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    //center
    [windowController.window center];

    //show it
    [windowController showWindow:self];
    
    //make it key window
    [[windowController window] makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//toggle (status) bar icon
-(void)toggleIcon:(BOOL)state
{
    //dbg msg
    os_log_debug(logHandle, "toggling icon state");
    
    //show?
    // init and show status bar item
    if(YES == state)
    {
        //already showing?
        if(nil != self.statusBarItemController)
        {
            //bail
            goto bail;
        }
        
        //alloc/load status bar icon/menu
        // will configure, and show popup/menu
        statusBarItemController = [[StatusBarItem alloc] init:self.statusMenu];
    }
    
    //hide?
    else
    {
        //already removed?
        if(nil == self.statusBarItemController)
        {
            //bail
            goto bail;
        }
        
        //remove status item
        [self.statusBarItemController removeStatusItem];
        
        //unset
        self.statusBarItemController = nil;
    }
    
bail:
    
    return;
}

//set app foreground/background
-(void)setActivationPolicy
{
    //visible window
    BOOL visibleWindow = NO;
    
    //dbg msg(s)
    os_log_debug(logHandle, "setting app's activation policy");
    os_log_debug(logHandle, "windows: %{public}@", NSApp.windows);
    
    //find any visible windows
    for(NSWindow* window in NSApp.windows)
    {
        //ignore status bar
        if(YES == [window.className isEqualToString:@"NSStatusBarWindow"])
        {
            //skip
            continue;
        }
        
        //visible?
        if(YES == window.isVisible)
        {
            //set flag
            visibleWindow = YES;
            
            //done
            break;
        }
    }
    
    //any windows?
    //bring app to foreground
    if(YES == visibleWindow)
    {
        //dbg msg
        os_log_debug(logHandle, "window(s) visible, setting policy: NSApplicationActivationPolicyRegular");
        
        //foreground
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    }
    
    //no more windows
    // send app to background
    else
    {
        //dbg msg
        os_log_debug(logHandle, "window(s) not visible, setting policy: NSApplicationActivationPolicyAccessory");
        
        //background
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    }
    
    return;
}

//call into Update obj
// check to see if there an update?
-(void)check4Update
{
    //update obj
    Update* update = nil;
    
    //init update obj
    update = [[Update alloc] init];
    
    //check for update
    // ->'updateResponse newVersion:' method will be called when check is done
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
    //handle response
    // new version, show popup
    switch (result)
    {
        //error
        case Update_Error:
            
            //err msg
            os_log_error(logHandle, "ERROR: update check failed");
            break;
            
        //no updates
        case Update_None:
            
            //dbg msg
            os_log_debug(logHandle, "no updates available");
            break;
            
        //this version of macOS, not supported
        case Update_NotSupported:
            
            //dbg msg
            os_log_debug(logHandle, "update available, but not for this version of macOS");
            break;
             
        //new version
        case Update_Available:
            
            //dbg msg
            os_log_debug(logHandle, "a new version (%@) is available", newVersion);

            //alloc update window
            updateWindowController = [[UpdateWindowController alloc] initWithWindowNibName:@"UpdateWindow"];
            
            //configure
            [self.updateWindowController configure:[NSString stringWithFormat:NSLocalizedString(@"a new version (%@) is available!", @"a new version (%@) is available!"), newVersion] buttonTitle:NSLocalizedString(@"Update",@"Update")];
            
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

@end
