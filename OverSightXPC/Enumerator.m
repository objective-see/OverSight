//
//  Enumerator.m
//  cameraUsers
//
//  Created by Patrick Wardle on 9/9/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Enumerator.h"
#import "../Shared/Logging.h"
#import "../Shared/Utilities.h"

#import <libproc.h>
#import <sys/sysctl.h>

//ignored mach sender procs
// TODO: maybe just ignore apple signed daemons/bg procs!?
static NSArray* ignoredProcs = nil;

@implementation Enumerator

@synthesize machSenders;
@synthesize videoActive;

//init
-(instancetype)init
{
    //init
    if(self = [super init])
    {
        //alloc dictionary
        machSenders = [NSMutableDictionary dictionary];
        
        //init ignored procs
        ignoredProcs = @[
                      @"/sbin/launchd",
                      @"/usr/libexec/lsd",
                      @"/usr/sbin/notifyd",
                      @"/usr/sbin/syslogd",
                      @"/usr/sbin/cfprefsd",
                      @"/usr/libexec/opendirectoryd",
                      @"/usr/libexec/UserEventAgent",
                      @"/System/Library/CoreServices/launchservicesd",
                      @"/System/Library/Frameworks/OpenGL.framework/Versions/A/Libraries/CVMServer",
                      @"/System/Library/Frameworks/CoreGraphics.framework/Versions/A/Resources/WindowServer",
                      @"/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/CarbonCore.framework/Versions/A/Support/coreservicesd",
                      @"/System/Library/Frameworks/VideoToolbox.framework/Versions/A/XPCServices/VTDecoderXPCService.xpc/Contents/MacOS/VTDecoderXPCService"
                      ];
    }
    
    return self;
}

//singleton interface
+(id)sharedManager
{
    //instance
    static Enumerator *sharedEnumerator = nil;
 
    //once token
    static dispatch_once_t onceToken;
    
    //init
    // ->only exec'd once though :)
    dispatch_once(&onceToken, ^{
        
        //init
        sharedEnumerator = [[self alloc] init];
        
    });
    
    return sharedEnumerator;
}

//find 'VDCAssistant' or 'AppleCameraAssistant'
-(pid_t)findCameraAssistant
{
    //pid of assistant
    pid_t cameraAssistant = 0;
    
    //status
    int status = -1;
    
    //# of procs
    int numberOfProcesses = 0;
    
    //array of pids
    pid_t* pids = NULL;
    
    //process path
    NSString* processPath = nil;
    
    //get # of procs
    numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    
    //alloc buffer for pids
    pids = calloc(numberOfProcesses, sizeof(pid_t));
    
    //get list of pids
    status = proc_listpids(PROC_ALL_PIDS, 0, pids, numberOfProcesses * sizeof(pid_t));
    if(status < 0)
    {
        //bail
        goto bail;
    }
    
    //iterate over all pids
    // ->get name for each via helper function
    for(int i = 0; i < numberOfProcesses; ++i)
    {
        //skip blank pids
        if(0 == pids[i])
        {
            //skip
            continue;
        }
        
        //get name
        processPath = getProcessPath(pids[i]);
        if( (nil == processPath) ||
           (0 == processPath.length) )
        {
            //skip
            continue;
        }
        
        //is 'VDCAssistant'?
        if(YES == [processPath isEqualToString:VDC_ASSISTANT])
        {
            //save
            cameraAssistant = pids[i];
            
            //pau
            break;
        }
        
        //is 'AppleCameraAssistant'?
        else if(YES == [processPath isEqualToString:APPLE_CAMERA_ASSISTANT])
        {
            //save
            cameraAssistant = pids[i];
            
            //pau
            break;
        }
    }
    
//bail
bail:
    
    //free buffer
    if(NULL != pids)
    {
        //free
        free(pids);
    }
    
    return cameraAssistant;
}

//forever, baseline by getting all current procs that have sent a mach msg to *Assistant
// ->ensures its only invoke while camera is not in use, so these are all just baselined procs
-(void)start
{
    //baseline forever
    // ->though logic will skip if video is active
    while(YES)
    {
        //sync baselining
        @synchronized(self)
        {
            //only baseline if video isn't active
            if(YES != self.videoActive)
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"baselining mach senders...");
                
                //enumerate procs that have send mach messages
                self.machSenders = [self enumMachSenders:[self findCameraAssistant]];
                
                //dbg msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"baselined mach senders: %@", self.machSenders]);
            }
        }
        
        //nap for a minute
        [NSThread sleepForTimeInterval:60];
    }
    
    return;
}

//enumerate all (recent) process that appear to be using video
-(NSMutableArray*)enumVideoProcs
{
    //current procs
    NSMutableArray* videoProcs = nil;
    
    //mach senders
    NSMutableDictionary* currentSenders = nil;
    
    //candidate video procs
    // ->those that have new mach message
    NSMutableArray* candidateVideoProcs = nil;
    
    //pid of camera assistant process
    pid_t cameraAssistant = 0;
    
    //alloc
    candidateVideoProcs = [NSMutableArray array];
    
    //sync this logic
    // ->prevent baselining thread from doing anything
    @synchronized(self)
    {

    //find 'VDCAssistant' or 'AppleCameraAssistant'
    cameraAssistant = [self findCameraAssistant];
    if(0 == cameraAssistant)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to find VDCAssistant/AppleCameraAssistant process");
        
        //bail
        goto bail;
    }
    
    //get procs that currrently have sent Mach msg to *Assistant
    // ->returns dictionary of process id, and number of mach messages
    currentSenders = [self enumMachSenders:cameraAssistant];
        
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"current mach senders: %@", currentSenders]);
    
    //remove any known/existing senders
    for(NSNumber* processID in currentSenders.allKeys)
    {
        //add any candidate procs
        // ->those that have new mach message
        if( [currentSenders[processID] intValue] > [self.machSenders[processID] intValue])
        {
            //add
            [candidateVideoProcs addObject:processID];
        }
        
        /*
        
        //remove existing ones
        if( (nil != self.machSenders[processID]) &&
            ([currentSenders[processID] intValue]) <= [self.machSenders[processID] intValue])
        {
            //remove
            [currentSenders removeObjectForKey:processID];
        }
         
        */
    }
        
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"candidate video procs: %@", candidateVideoProcs]);
    
    //save to baseline
    // TODO: test that this works, esp if cnt goes down!! (facetime battery mode)
    //[self.machSenders addEntriesFromDictionary:currentSenders];
    //update
    self.machSenders = currentSenders;
    
    //invoke 'sample' to confirm that candidates are using CMIO/video inputs
    videoProcs = [self sampleCandidates:candidateVideoProcs];
    
    }//sync
    
//bail
bail:
    
    return videoProcs;
}

//get procs that currrently have sent Mach msg to *Assistant
// ->returns dictionary of process id, and number of mach messages
-(NSMutableDictionary*)enumMachSenders:(pid_t)cameraAssistant
{
    //senders
    NSMutableDictionary* senders = nil;
    
    //results from 'lsmp' cmd
    NSString* results = nil;
    
    //substrings
    NSArray* subStrings = nil;
    
    //process id
    NSNumber* processID = nil;
    
    //alloc
    senders = [NSMutableDictionary dictionary];
    
    //exec 'lsmp' w/ pid of camera asssistant to get mach ports
    results = [[NSString alloc] initWithData:execTask(LSMP, @[@"-p", @(cameraAssistant).stringValue]) encoding:NSUTF8StringEncoding];
    if( (nil == results) ||
        (0 == results.length) )
    {
        //bail
        goto bail;
    }
    
    //parse results
    // ->looking for (<pid>) process name
    for(NSString* line in [results componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\n"]])
    {
        //skip blank lines
        if(0 == line.length)
        {
            //skip
            continue;
        }
        
        //parse on '()'
        // TODO: improve this!
        subStrings = [line componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"()"]];
        if(subStrings.count < 3)
        {
            //skip
            continue;
        }
        
        //skip 'unknown' processes
        // output looks like "(-) Unknown Process"
        if(YES == [[subStrings objectAtIndex:0x1] isEqualToString:@"-"])
        {
            //skip
            continue;
        }
        
        //extract process id
        // ->insides '()', so will be second substring
        processID = @([[subStrings objectAtIndex:0x1] integerValue]);
        if(nil == processID)
        {
            //skip
            continue;
        }
        
        //ignore self
        if(cameraAssistant == processID.intValue)
        {
            //skip
            continue;
        }
        
        //ignore apple daemons (that send mach messages, etc)
        if(YES == [ignoredProcs containsObject:getProcessPath(processID.intValue)])
        {
            //skip
            continue;
        }
        
        //add/inc to dictionary
        senders[processID] = @([senders[processID] unsignedIntegerValue] + 1);
    }
    
//bail
bail:
    
    return senders;
}

//invoke 'sample' to confirm candidates are using CMIO/video inputs
-(NSMutableArray*)sampleCandidates:(NSArray*)currentSenders
{
    //current procs
    NSMutableArray* videoProcs = nil;
    
    //results from 'sample' cmd
    NSString* results = nil;
    
    //alloc
    videoProcs = [NSMutableArray array];
    
    //invoke 'sample' on each
    // TODO: delete tmp file? 'Sample analysis of process 37370 written to file /tmp/FaceTime_2016-09-10_081703_TAwB.sample.txt' (written 2 std err?)
    for(NSNumber* processID in currentSenders)
    {
        //exec 'sample' to get threads/dylibs
        results = [[NSString alloc] initWithData:execTask(SAMPLE, @[processID.stringValue, @"1"]) encoding:NSUTF8StringEncoding];
        if( (nil == results) ||
            (0 == results.length) )
        {
            //skip
            continue;
        }

        //for now, just check for 'CMIOGraph::DoWork'
        // TODO: could look for dylibs, other calls, etc
        if(YES != [results containsString:@"CMIOGraph::DoWork"])
        {
            //skip
            continue;
        }
        
        //looks like a video proc!
        [videoProcs addObject:processID];
    }
    
    return videoProcs;
}

//set status of video
-(void)updateVideoStatus:(BOOL)isEnabled
{
    //sync
    @synchronized(self)
    {
        //set
        self.videoActive = isEnabled;
    }
    
    return;
}

@end


