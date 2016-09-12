//
//  AboutWindowController.m
//  OverSight
//
//  Created by Patrick Wardle on 7/15/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Utilities.h"
#import "AboutWindowController.h"

@implementation AboutWindowController

@synthesize versionLabel;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
}

//automatically invoked when window is loaded
// ->set to white
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    //set version sting
    [self.versionLabel setStringValue:[NSString stringWithFormat:@"version: %@", getAppVersion()]];

    return;
}

//automatically invoked when user clicks 'more info'
// ->load products webpage view their default browser
-(IBAction)moreInfo:(id)sender
{
    //open URL
    // ->invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PRODUCT_URL]];
        
    return;
}
@end
