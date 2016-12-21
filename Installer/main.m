//
//  main.m
//  OverSight
//
//  Created by Patrick Wardle on 7/15/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "main.h"
#import "Consts.h"
#import "Configure.h"
#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[])
{
    //return var
    int retVar = -1;
    
    @autoreleasepool
    {
        //handle '-install' / '-uninstall'
        // ->this performs non-UI logic for easier automated deployment
        if( (argc >= 2) &&
            ( (0 == strcmp(argv[1], CMD_INSTALL)) || (0 == strcmp(argv[1], CMD_UNINSTALL)) ) )
        {
            //first check rooot
            if(0 != geteuid())
            {
                //err msg
                printf("\nERROR: '%s' option, requires root\n\n", argv[1]);
                
                //bail
                goto bail;
            }
            
            //handle install
            if(0 == strcmp(argv[1], CMD_INSTALL))
            {
                //install
                if(YES != cmdlineInstall())
                {
                    //err msg
                    printf("\nERROR: install failed\n\n");
                    
                    //bail
                    goto bail;
                }
                
                //dbg msg
                printf("OVERSIGHT: install ok!\n");
                
                //happy
                retVar = 0;
            }
            
            //handle uninstall
            else if(0 == strcmp(argv[1], CMD_UNINSTALL))
            {
                //uninstall
                if(YES != cmdlineUninstall())
                {
                    //err msg
                    printf("\nERROR: install failed\n\n");
                }
                
                //dbg msg
                printf("OVERSIGHT: uninstall ok!\n");
                
                //happy
                retVar = 0;
            }
        
            //bail
            goto bail;
            
        }//args
        
        //check for r00t
        // ->then spawn self via auth exec
        if(0 != geteuid())
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"non-root installer instance");
            
            //spawn as root
            if(YES != spawnAsRoot(argv[0]))
            {
                //err msg
                logMsg(LOG_ERR, @"failed to spawn self as r00t");
                
                //bail
                goto bail;
            }
            
            //happy
            retVar = 0;
        }
        
        //otherwise
        // ->just kick off app, as we're root now
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"root installer instance");
            
            //app away
            retVar = NSApplicationMain(argc, (const char **)argv);
        }
        
    }//pool

//bail
bail:
    
    return retVar;
}

//spawn self as root
BOOL spawnAsRoot(const char* path2Self)
{
    //return/status var
    BOOL bRet = NO;
    
    //authorization ref
    AuthorizationRef authorizatioRef = {0};
    
    //args
    char *args[] = {NULL};
    
    //flag creation of ref
    BOOL authRefCreated = NO;
    
    //status code
    OSStatus osStatus = -1;
    
    //create authorization ref
    // ->and check
    osStatus = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizatioRef);
    if(errAuthorizationSuccess != osStatus)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"AuthorizationCreate() failed with %d", osStatus]);
        
        //bail
        goto bail;
    }
    
    //set flag indicating auth ref was created
    authRefCreated = YES;
    
    //spawn self as r00t w/ install flag (will ask user for password)
    // ->and check
    osStatus = AuthorizationExecuteWithPrivileges(authorizatioRef, path2Self, 0, args, NULL);
    
    //check
    if(errAuthorizationSuccess != osStatus)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"AuthorizationExecuteWithPrivileges() failed with %d", osStatus]);
        
        //bail
        goto bail;
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    //free auth ref
    if(YES == authRefCreated)
    {
        //free
        AuthorizationFree(authorizatioRef, kAuthorizationFlagDefaults);
    }
    
    return bRet;
}

//install
BOOL cmdlineInstall()
{
    //do it!
    return [[[Configure alloc] init] configure:ACTION_INSTALL_FLAG];
}

//uninstall
BOOL cmdlineUninstall()
{
    //do it!
    return [[[Configure alloc] init] configure:ACTION_UNINSTALL_FLAG];
}

