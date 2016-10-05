//
//  AppDelegate.m
//  OverSight
//
//  Created by Patrick Wardle on 9/01/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Configure.h"
#import "Exception.h"
#import "Utilities.h"
#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

@synthesize aboutWindowController;
@synthesize errorWindowController;
@synthesize configureWindowController;

//main app interface
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //config object
    Configure* configureObj = nil;
    
    //first thing...
    // ->install exception handlers
    installExceptionHandlers();
    
    //alloc/init Config obj
    configureObj = [[Configure alloc] init];

    //show window
    [self displayConfigureWindow:[configureObj isInstalled]];
    
//bail
bail:
    
    return;
    
}

//automatically invoked when user clicks 'About/Info'
// ->show about window
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
    
    return;
}

//display configuration window w/ 'install' || 'uninstall' button
-(void)displayConfigureWindow:(BOOL)isInstalled
{
    //alloc/init
    configureWindowController = [[ConfigureWindowController alloc] initWithWindowNibName:@"ConfigureWindowController"];
    
    //display it
    // ->call this first to so that outlets are connected
    [self.configureWindowController display];
    
    //configure it
    [self.configureWindowController configure:isInstalled];
    
    return;
}

//display error window
-(void)displayErrorWindow:(NSDictionary*)errorInfo
{
    //alloc error window
    errorWindowController = [[ErrorWindowController alloc] initWithWindowNibName:@"ErrorWindowController"];
    
    //main thread
    // ->just show UI alert, unless its fatal (then load URL)
    if(YES == [NSThread isMainThread])
    {
        //non-fatal errors
        // ->show error popup
        if(YES != [errorInfo[KEY_ERROR_URL] isEqualToString:FATAL_ERROR_URL])
        {
            //display it
            // ->call this first to so that outlets are connected
            [self.errorWindowController display];
            
            //configure it
            [self.errorWindowController configure:errorInfo];
        }
        //fatal error
        // ->launch browser to go to fatal error page, then exit
        else
        {
            //launch browser
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:errorInfo[KEY_ERROR_URL]]];
            
            //then exit
            [NSApp terminate:self];
        }
    }
    //background thread
    // ->have to show error window on main thread
    else
    {
        //show alert
        // ->in main UI thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //display it
            // ->call this first to so that outlets are connected
            [self.errorWindowController display];
            
            //configure it
            [self.errorWindowController configure:errorInfo];
            
        });
    }
    
    return;
}

@end
