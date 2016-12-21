//
//  AboutWindowController.h
//  OverSight
//
//  Created by Patrick Wardle on 7/15/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RememberWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//version label/string
@property (weak) IBOutlet NSTextField *windowText;

/* METHODS */

//configure window w/ dynamic text
-(void)configure:(NSUserNotification*)notification;

@end
