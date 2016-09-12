//
//  AboutWindowController.h
//  OverSight
//
//  Created by Patrick Wardle on 7/15/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AboutWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//version label/string
@property (weak) IBOutlet NSTextField *versionLabel;

/* METHODS */

//invoked when user clicks 'more info' button
// ->open KK's webpage
- (IBAction)moreInfo:(id)sender;

@end
