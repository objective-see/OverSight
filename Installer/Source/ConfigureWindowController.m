//
//  file: ConfigureWindowController.m
//  project: OverSight (config)
//  description: install/uninstall window logic
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import OSLog;

#import "consts.h"
#import "Configure.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "ConfigureWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation ConfigureWindowController

@synthesize statusMsg;
@synthesize configureObj;
@synthesize moreInfoButton;
@synthesize appActivationObserver;

//automatically called when nib is loaded
// just center window, alloc some objs, etc
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //when supported
    // indicate title bar is transparent (too)
    if(YES == [self.window respondsToSelector:@selector(titlebarAppearsTransparent)])
    {
        //set transparency
        self.window.titlebarAppearsTransparent = YES;
    }
    
    //make first responder
    // calling this without a timeout sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //and make it first responder
        [self.window makeFirstResponder:self.installButton];
        
    });

    //init configure object
    if(nil == self.configureObj)
    {
        //alloc/init Config obj
        configureObj = [[Configure alloc] init];
    }
    
    return;
}

//configure window/buttons
// also brings window to front
-(void)configure
{
    //flag
    BOOL isInstalled = NO;
    
    //init flag
    isInstalled = [self.configureObj isInstalled];
    
    //set window title
    [self window].title = [NSString stringWithFormat:@"version %@", getAppVersion()];
    
    //init status msg
    [self.statusMsg setStringValue:@"...protects your webcam & microphone!"];
    
    //uninstall via app?
    // just enable uinstall button
    if(YES == [NSProcessInfo.processInfo.arguments containsObject:CMD_UNINSTALL_VIA_UI])
    {
        //enable uninstall
        self.uninstallButton.enabled = YES;
        
        //disable install
        self.installButton.enabled = NO;
        
        //make uninstall button first responder
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            
            //set first responder
            [self.window makeFirstResponder:self.uninstallButton];
            
        });
        
    }

    //app already installed?
    // enable 'uninstall' button
    // change 'install' button to say 'upgrade'
    else if(YES == isInstalled)
    {
        //enable 'uninstall'
        self.uninstallButton.enabled = YES;
        
        //set to 'upgrade'
        self.installButton.title = ACTION_UPGRADE;
    }
    
    //otherwise disable
    else
    {
        //disable
        self.uninstallButton.enabled = NO;
    }
    
    //set delegate
    [self.window setDelegate:self];

    return;
}

//display (show) window
// center, make front, set bg to white, etc
-(void)display
{
    //center window
    [[self window] center];
    
    //show (now configured) windows
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }

    return;
}

//button handler for configure window
// install/uninstall/close logic
-(IBAction)configureButtonHandler:(id)sender
{
    //action
    NSInteger action = 0;
    
    //app path
    NSURL* appPath = nil;

    //app config
    NSWorkspaceOpenConfiguration* configuration = nil;
    
    //grab tag
    action = ((NSButton*)sender).tag;
    
    //dbg msg
    os_log_debug(logHandle, "handling action click: %{public}@ (tag: %ld)", ((NSButton*)sender).title, (long)action);
    
    //process button
    switch(action)
    {
        //install/uninstall
        case ACTION_INSTALL_FLAG:
        case ACTION_UNINSTALL_FLAG:
        {
            //disable 'x' button
            // don't want user killing app during install/upgrade
            [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:NO];
            
            //clear status msg
            self.statusMsg.stringValue = @"";
            
            //force redraw of status msg
            // sometime doesn't refresh (e.g. slow VM)
            self.statusMsg.needsDisplay = YES;
            
            //invoke logic to install/uninstall
            // do in background so UI doesn't block
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
               //install/uninstall
               [self lifeCycleEvent:action];
            });
            
            break;
        }
            
        //show 'support' view
        case ACTION_SHOW_NOTIFICATIONS:
        {
            //dbg msg
            os_log_debug(logHandle, "showing 'notifcations' view");
            
            //show view
            [self showView:self.notificationsView firstResponder:self.gotoSupportViewButton];
            
            //unset window title
            self.window.title = @"";
            
            break;
        }
        
        //show 'support' view
        case ACTION_SHOW_SUPPORT:
        {
            //dbg msg
            os_log_debug(logHandle, "showing 'support' view");
            
            //show view
            [self showView:self.supportView firstResponder:self.supportButton];
            
            //unset window title
            self.window.title = @"";
            
            break;
        }
            
        //support, yes!
        case ACTION_SUPPORT:
            
            //open URL
            // invokes user's default browser
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PATREON_URL]];
        
            //fall thru as we want to launch app and terminate
            
        //close
        // on non-error, launch login item
        case ACTION_CLOSE_FLAG:
        {
            //coming from support view?
            // launch helper/login item
            if(YES == self.supportView.window.isVisible)
            {
                //init app path
                appPath = [NSURL fileURLWithPath:[@"/Applications" stringByAppendingPathComponent:APP_NAME]];
                
                //alloc configuration
                configuration = [[NSWorkspaceOpenConfiguration alloc] init];
                
                //set args
                configuration.arguments = @[INITIAL_LAUNCH];
                
                //unset recent
                configuration.addsToRecentItems = NO;
                
                //dbg msg
                os_log_debug(logHandle, "now launching: %{public}@", appPath.path);
                                
                //launch it
                [NSWorkspace.sharedWorkspace openApplicationAtURL:appPath configuration:configuration completionHandler:^(NSRunningApplication * _Nullable application, NSError * _Nullable error)
                {
                    #pragma unused(application)
                    
                    //error?
                    if(nil != error)
                    {
                        //err msg
                        os_log_error(logHandle, "ERROR: failed to launch %{public}@ (error: %{public}@)", appPath, error);
                    }
                    
                    //close window
                    // triggers cleanup logic
                    dispatch_sync(dispatch_get_main_queue(),
                    ^{
                        [self.window close];
                    });
                    
                }];
            }
           
            else
            {
                //close window
                // triggers cleanup logic
                [self.window close];
            }
           
            break;
        }
        
        //default
        default:
            
            break;
    }
    
    return;
}

//show view
// adds to main window, resizes, etc
-(void)showView:(NSView*)view firstResponder:(NSButton*)firstResponder
{
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //set white
        view.layer.backgroundColor = [NSColor whiteColor].CGColor;
    }
    
    //set content view size
    self.window.contentSize = view.frame.size;
    
    //update config view
    self.window.contentView = view;

    //make 'next' button first responder
    // calling this without a timeout, sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //set first responder
        [self.window makeFirstResponder:firstResponder];
        
    });
    
    return;
}

//button handler for '?' button (on an error)
// load objective-see's documentation for error(s) in default browser
-(IBAction)info:(id)sender
{
    #pragma unused(sender)
    
    //open URL
    // invokes user's default browser
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:ERRORS_URL]];
    
    return;
}

//perform install | uninstall via Control obj
// invoked on background thread so that UI doesn't block
-(void)lifeCycleEvent:(NSInteger)event
{
    //status var
    BOOL status = NO;
    
    //begin event
    // updates ui on main thread
    dispatch_sync(dispatch_get_main_queue(),
    ^{
        //begin
        [self beginEvent:event];
    });
    
    //in background
    // perform action (install | uninstall)
    status = [self.configureObj configure:event];
    
    //complete event
    // updates ui on main thread
    dispatch_async(dispatch_get_main_queue(),
    ^{
        //complete
        [self completeEvent:status event:event];
    });
    
    return;
}

//begin event
// basically just update UI
-(void)beginEvent:(NSInteger)event
{
    //status msg frame
    CGRect statusMsgFrame;
    
    //grab exiting frame
    statusMsgFrame = self.statusMsg.frame;
    
    //avoid activity indicator
    // shift frame shift delta
    statusMsgFrame.origin.x += FRAME_SHIFT;
    
    //update frame to align
    self.statusMsg.frame = statusMsgFrame;
    
    //align text left
    self.statusMsg.alignment = NSTextAlignmentLeft;
    
    //observe app activation
    // allows workaround where process indicator stops
    self.appActivationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSWorkspaceDidActivateApplicationNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        #pragma unused(notification)
        
        //show spinner
        self.activityIndicator.hidden = NO;
        
        //start spinner
        [self.activityIndicator startAnimation:nil];
        
    }];
    
    //install msg
    if(ACTION_INSTALL_FLAG == event)
    {
        //update status msg
        [self.statusMsg setStringValue:@"Installing..."];
    }
    //uninstall msg
    else
    {
        //update status msg
        [self.statusMsg setStringValue:@"Uninstalling..."];
    }
    
    //disable action button
    self.uninstallButton.enabled = NO;
    
    //disable cancel button
    self.installButton.enabled = NO;
    
    //show spinner
    self.activityIndicator.hidden = NO;
    
    //start spinner
    [self.activityIndicator startAnimation:nil];
    
    return;
}

//complete event
// update UI after background event has finished
-(void)completeEvent:(BOOL)success event:(NSInteger)event
{
    //status msg frame
    CGRect statusMsgFrame;
    
    //action
    NSString* action = nil;
    
    //result msg
    NSMutableString* resultMsg = nil;
    
    //msg font
    NSColor* resultMsgColor = nil;
    
    //remove app activation observer
    if(nil != self.appActivationObserver)
    {
        //remove
        [[NSNotificationCenter defaultCenter] removeObserver:self.appActivationObserver];
        
        //unset
        self.appActivationObserver = nil;
    }
    
    //set action msg for install
    if(ACTION_INSTALL_FLAG == event)
    {
        //set msg
        action = @"install";
    }
    //set action msg for uninstall
    else
    {
        //set msg
        action = @"uninstall";
    }
    
    //success
    if(YES == success)
    {
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"☑️ %@: %@ed!\n", PRODUCT_NAME, action];
    }
    //failure
    else
    {
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"⚠️ Error: %@ failed", action];
        
        //show 'get more info' button
        self.moreInfoButton.hidden = NO;
    }
    
    //stop/hide spinner
    [self.activityIndicator stopAnimation:nil];
    
    //hide spinner
    self.activityIndicator.hidden = YES;
    
    //grab exiting frame
    statusMsgFrame = self.statusMsg.frame;
    
    //shift back since activity indicator is gone
    statusMsgFrame.origin.x -= FRAME_SHIFT;
    
    //update frame to align
    self.statusMsg.frame = statusMsgFrame;
    
    //set font to bold
    self.statusMsg.font = [NSFont fontWithName:@"Menlo-Bold" size:13];
    
    //set msg color
    self.statusMsg.textColor = resultMsgColor;
    
    //set status msg
    self.statusMsg.stringValue = resultMsg;
    
    //install success?
    // set button title & tag for 'next'
    if( (YES == success) &&
        (ACTION_INSTALL_FLAG == event) )
    {
        //next
        self.installButton.title = ACTION_NEXT;
        
        //set tag
        self.installButton.tag = ACTION_SHOW_NOTIFICATIONS;
    }
    //otherwise
    // set button and tag for close/exit
    else
    {
        //close
        self.installButton.title = ACTION_CLOSE;
        
        //update it's tag
        // will allow button handler method process
        self.installButton.tag = ACTION_CLOSE_FLAG;
        
        //(re)enable 'x' button
        [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:YES];
    }
    
    //enable
    self.installButton.enabled = YES;

    //...and highlighted
    [self.window makeFirstResponder:self.installButton];

    //(re)make window window key
    [self.window makeKeyAndOrderFront:self];
    
    //(re)make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//perform any cleanup/termination
// for now, just call into Config obj to remove helper
-(BOOL)cleanup
{
    //flag
    BOOL cleanedUp = NO;
    
    //dbg msg
    os_log_debug(logHandle, "cleaning up...");
    
    //remove helper
    if(YES != [self.configureObj removeHelper])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to remove config helper");
        
        //bail
        goto bail;
    }
    
    //happy
    cleanedUp = YES;
    
bail:

    return cleanedUp;
}

//automatically invoked when window is closing
// perform cleanup logic, then manually terminate app
-(void)windowWillClose:(NSNotification *)notification
{
    #pragma unused(notification)
    
    //cleanup in background
    // then exit application
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //cleanup
        [self cleanup];
        
        //exit on main thread
        dispatch_async(dispatch_get_main_queue(),
        ^{
            
            //dbg msg
            os_log_debug(logHandle, "%{public}@ exiting...", [NSProcessInfo.processInfo.arguments.firstObject lastPathComponent]);
            
            //exit
            [NSApp terminate:self];
        });
    });

    return;
}

@end
