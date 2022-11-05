//
//  file: Update.m
//  project: OverSight (shared)
//  description: checks for new versions
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import OSLog;

#import "consts.h"
#import "Update.h"
#import "utilities.h"
#import "AppDelegate.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation Update

//check for an update
// ->will invoke app delegate method to update UI when check completes
-(void)checkForUpdate:(void (^)(NSUInteger result, NSString* latestVersion))completionHandler
{
    //info
    __block NSDictionary* productInfo = nil;
    
    //result
    __block NSInteger result = Update_None;

    //get latest version in background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //latest version
        NSString* latestVersion = nil;
        
        //supported OS
        NSOperatingSystemVersion supportedOS = {0};
        
        //get product info
        productInfo = [self getProductInfo:PRODUCT_NAME];
        if(nil == productInfo)
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed retrieve product info (for update check) from %{public}@", PRODUCT_VERSIONS_URL);
            
            //error
            result = Update_Error;
        }
        //got remote product info
        // check supported OS and latest version
        else
        {
            //init supported OS
            supportedOS.majorVersion = [productInfo[SUPPORTED_OS_MAJOR] intValue];
            supportedOS.minorVersion = [productInfo[SUPPORTED_OS_MINOR] intValue];
            
            //extract latest version
            latestVersion = productInfo[LATEST_VERSION];
            
            //supported version of macOS?
            if(YES != [NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:supportedOS])
            {
                //dbg msg
                os_log_debug(logHandle, "latest version requires macOS %ld.%ld ...but current macOS is %{public}@", supportedOS.majorVersion, supportedOS.minorVersion, NSProcessInfo.processInfo.operatingSystemVersionString);
                
                //unsupported
                result = Update_NotSupported;
            }
            
            //latest version is new(er)?
            else if(nil != latestVersion)
            {
                //check app version and latest version
                if(NSOrderedAscending == [getAppVersion() compare:latestVersion options:NSNumericSearch])
                {
                    //new update!
                    result = Update_Available;
                }
            }
        }
        
        //invoke app delegate method
        // will update UI/show popup if necessary
        dispatch_async(dispatch_get_main_queue(),
        ^{
            completionHandler(result, latestVersion);
        });
    });
    
    return;
}

//read JSON file w/ products
// return dictionary w/ info about this product
-(NSDictionary*)getProductInfo:(NSString*)product
{
    //product version(s) data
    NSDictionary* products = nil;
    
    //get json file (products) from remote URL
    @try
    {
        //convert
        products = [NSJSONSerialization JSONObjectWithData:[[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:PRODUCT_VERSIONS_URL]] options:0 error:nil];
    }
    @catch(NSException* exception)
    {
        ;
    }
    
bail:
    
    return products[product];
}

@end
