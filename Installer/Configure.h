//
//  Configure.h
//  OverSight
//
//  Created by Patrick Wardle on 9/01/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef __WYS_Configure_h
#define __WYS_Configure_h

#import <Foundation/Foundation.h>

@interface Configure : NSObject
{
    
}


/* METHODS */

//determine if extension is installed
-(BOOL)isInstalled;

//invokes appropriate install || uninstall logic
-(BOOL)configure:(NSUInteger)parameter;

//install
-(BOOL)install;

//uninstall
-(BOOL)uninstall:(NSUInteger)type;

//build path to logged in user's app support directory + '/Objective-See'
-(NSString*)appSupportPath:(NSString*)user;

@end

#endif
