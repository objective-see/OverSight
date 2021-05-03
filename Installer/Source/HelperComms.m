//
//  file: HelperComms.h
//  project: OverSight (config)
//  description: interface to talk to blessed installer (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import OSLog;
@import Foundation;

#import "consts.h"
#import "AppDelegate.h"
#import "HelperComms.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation HelperComms

@synthesize daemon;
@synthesize xpcServiceConnection;

//init
// create XPC connection & set remote obj interface
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc/init
        xpcServiceConnection = [[NSXPCConnection alloc] initWithMachServiceName:CONFIG_HELPER_ID options:0];
        
        //set remote object interface
        self.xpcServiceConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
        
        //resume
        [self.xpcServiceConnection resume];
    }
    
    return self;
}

//uninstall
-(BOOL)uninstall:(NSString*)prefsDirectory
{
    //result
    __block BOOL result = NO;
    
    //dbg msg
    os_log_debug(logHandle, "invoking 'uninstall' XPC method, with %{public}@", prefsDirectory);
    
    //uninstall
    [[self.xpcServiceConnection synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute 'uninstall' method on helper tool (error: %@)", proxyError);
        
    }] uninstall:[[NSBundle mainBundle] bundlePath] prefs:prefsDirectory reply:^(NSNumber* xpcResult)
    {
         //capture results
         result = [xpcResult boolValue];
    }];
    
    return result;
}

//cleanup
-(BOOL)cleanup
{
    //result
    __block BOOL result = NO;
    
    //dbg msg
    os_log_debug(logHandle, "invoking 'cleanup' XPC method");
    
    //remove
    [[(NSXPCConnection*)self.xpcServiceConnection synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute 'remove' method on helper tool (error: %@)", proxyError);
          
    }] cleanup:^(NSNumber* xpcResult)
    {
        //capture results
        result = [xpcResult boolValue];
    }];
    
    return result;
}

@end
