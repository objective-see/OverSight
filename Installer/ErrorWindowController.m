//
//  ErrorWindowController.m
//  OverSight
//
//  Created by Patrick Wardle on 7/15/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "ErrorWindowController.h"

@interface ErrorWindowController ()

@end

@implementation ErrorWindowController

@synthesize errorURL;
@synthesize shouldExit;
@synthesize closeButton;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    return;
}

//configure the object/window
-(void)configure:(NSDictionary*)errorInfo
{
    //set error msg
    self.errMsg.stringValue = errorInfo[KEY_ERROR_MSG];
    
    //set error sub msg
    self.errSubMsg.stringValue = errorInfo[KEY_ERROR_SUB_MSG];
    
    //save exit
    self.shouldExit = [errorInfo[KEY_ERROR_SHOULD_EXIT] boolValue];
    
    //grab optional error url
    if(nil != errorInfo[KEY_ERROR_URL])
    {
        //extract/convert
        self.errorURL = [NSURL URLWithString:errorInfo[KEY_ERROR_URL]];
    }
    
    //when exiting
    // ->change 'close' to 'exit'
    if(YES == self.shouldExit)
    {
        //change title
        self.closeButton.title = @"Exit";
    }
    
    //for fatal errors
    // ->change 'Info' to 'help fix'
    if(YES == [[self.errorURL absoluteString] isEqualToString:FATAL_ERROR_URL])
    {
        //change title
        self.infoButton.title = @"Help Fix";
    }
    
    //set delegate
    [self.window setDelegate:self];
    
    return;
}

//display (show) window
-(void)display
{
    //show (now configured), alert
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //make 'close' have focus
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        //make close button active
        [self.window makeFirstResponder:closeButton];
        
    });
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    return;
}

//invoked when user clicks '?' (help button)
// ->open url with more info about the error(s)
-(IBAction)help:(id)sender
{
    //if a url was specified
    // ->use that one
    if(nil != self.errorURL)
    {
        //open URL
        // ->invokes user's default browser
        [[NSWorkspace sharedWorkspace] openURL:self.errorURL];
    }
    //use default URL
    else
    {
        //open URL
        // ->invokes user's default browser
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:ERRORS_URL]];
    }
    
    return;
}

//invoked when user clicks 'close'
// ->just close window
-(IBAction)close:(id)sender
{
    //close
    [self.window close];
    
    return;
}

//automatically invoked when window is closing
// ->exit the app if specified...
-(void)windowWillClose:(NSNotification *)notification
{
    //check if should exit process
    // ->e.g. an error during install, etc
    if(YES == self.shouldExit)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"exiting application");
        #endif
        
        //exit
        [NSApp terminate:self];
    }
    
    return;
}

@end
