//
//  Enumerator.m
//  cameraUsers
//
//  Created by Patrick Wardle on 9/9/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "main.h"
#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "Enumerator.h"

#import <libproc.h>
#import <sys/sysctl.h>

//ignored mach sender procs
static NSArray* ignoredProcs = nil;

@implementation Enumerator

@synthesize audioActive;
@synthesize userClients;
@synthesize videoActive;
@synthesize machSendersAudio;
@synthesize machSendersVideo;

//init
-(instancetype)init
{
    //init
    if(self = [super init])
    {
        //init ignored procs
        ignoredProcs = @[
                      @"/sbin/launchd",
                      @"/usr/libexec/lsd",
                      @"/usr/sbin/notifyd",
                      @"/usr/sbin/syslogd",
                      @"/usr/sbin/cfprefsd",
                      @"/usr/libexec/avconferenced",
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
    static Enumerator* sharedEnumerator = nil;
 
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

//forever, baseline by getting all current procs that have sent a mach msg to *Assistant / coreaudio
// ->logic only exec'd while camera/mic is not in use, so these are all just baselined procs
-(void)start
{
    //camera assistant
    pid_t cameraAssistant = 0;
    
    //baseline forever
    // ->though logic will skip if video or mic is active (respectively)
    while(YES)
    {
        //sync baselining
        @synchronized(self)
        {
            //only baseline if video isn't active
            if(YES != self.videoActive)
            {
                //dbg msg
                #ifdef DEBUG
                logMsg(LOG_DEBUG, @"baselining mach senders for video...");
                #endif
                
                //find camera assistant
                // ->first look for 'VDCAssistant'
                cameraAssistant = findProcess(VDC_ASSISTANT);
                if(0 == cameraAssistant)
                {
                    //look for 'AppleCameraAssistant'
                    cameraAssistant = findProcess(APPLE_CAMERA_ASSISTANT);
                }
                
                //sanity check
                if(0 == cameraAssistant)
                {
                    //nap for a minute
                    [NSThread sleepForTimeInterval:60];
                    
                    //next
                    continue;
                }
                
                //enumerate procs that have send mach messages
                self.machSendersVideo = [self enumMachSenders:cameraAssistant];
                
                //dbg msg
                #ifdef DEBUG
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %lu baselined mach senders: %@", (unsigned long)self.machSendersVideo.count, self.machSendersVideo]);
                #endif
            }
            
            //only baseline if audio isn't active
            if(YES != self.audioActive)
            {
                //dbg msg
                #ifdef DEBUG
                logMsg(LOG_DEBUG, @"baselining mach senders for audio...");
                #endif
                
                //enumerate procs that have send mach messages
                self.machSendersAudio = [self enumMachSenders:findProcess(CORE_AUDIO)];
                
                //dbg msg
                #ifdef DEBUG
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %lu baselined mach senders: %@", (unsigned long)self.machSendersAudio.count, self.machSendersVideo]);
                
                //dbg msg
                logMsg(LOG_DEBUG, @"baselining i/o registry entries for audio...");
                #endif
                
                //enumerate procs that have i/o registry entries
                self.userClients = [self enumDomainUserClients];
                
                //dbg msg
                #ifdef DEBUG
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %lu baselined i/or registry senders: %@", (unsigned long)self.userClients.count, self.userClients]);
                #endif
            }
        }
        
        //nap for a minute
        [NSThread sleepForTimeInterval:60];
    }
    
    return;
}

//enumerate all (recent) process that appear to be using video
-(NSMutableArray*)enumVideoProcs:(BOOL)polling
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
    
    //'frontmost' application
    pid_t activeApp = -1;
    
    //alloc
    candidateVideoProcs = [NSMutableArray array];
    
    //sync this logic
    // ->prevent baselining thread from doing anything
    @synchronized(self)
    {

    //first look for 'VDCAssistant'
    cameraAssistant = findProcess(VDC_ASSISTANT);
    if(0 == cameraAssistant)
    {
        //look for 'AppleCameraAssistant'
        cameraAssistant = findProcess(APPLE_CAMERA_ASSISTANT);
    }
    
    //sanity check
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
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %lu current mach senders: %@", (unsigned long)currentSenders.count, currentSenders]);
    #endif
    
    //remove any known/existing senders
    for(NSNumber* processID in currentSenders.allKeys)
    {
        //add any candidate procs
        // ->those that have new mach message
        if( [currentSenders[processID] intValue] > [self.machSendersVideo[processID] intValue])
        {
            //ignore client/requestor
            if(clientPID == processID.intValue)
            {
                //ignore
                continue;
            }
            
            //add
            [candidateVideoProcs addObject:processID];
        }
    }
        
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %lu candidate video procs: %@", (unsigned long)candidateVideoProcs.count, candidateVideoProcs]);
    #endif
    
    //update
    self.machSendersVideo = currentSenders;
        
    //didn't find any?
    // ->when not polling, add foreground process (and sample it below)
    if( (0 == candidateVideoProcs.count) &&
        (YES != polling))
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"didn't find any candidate video apps, and not polling, so will grab (and sample) active application");
        #endif
        
        //get active app
        activeApp = frontmostApplication();
        if(-1 != activeApp)
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found active application: %d", activeApp]);
            #endif
            
            //add it
            [candidateVideoProcs addObject:[NSNumber numberWithInt:activeApp]];
        }
    }
    
    //invoke 'sample' to confirm that candidates are using CMIO/video inputs
    // ->note, will skip FaceTime.app on macOS Sierra, as it doesn't do CMIO stuff directly
    videoProcs = [self sampleCandidates:candidateVideoProcs];
    
    }//sync
    
//bail
bail:
    
    return videoProcs;
}

//enumerate all (recent) process that appear to be using the mic
-(NSMutableArray*)enumAudioProcs
{
    //current procs
    NSMutableArray* audioProcs = nil;
    
    //current mach senders
    NSMutableDictionary* currentSenders = nil;
    
    //new senders
    NSMutableArray* newSenders = nil;
    
    //current domain user clients (from i/o registry)
    NSMutableDictionary* currentUserClients = nil;
    
    //new user clients
    NSMutableArray* newUserClients = nil;
    
    //candidate audio procs
    // ->those that have new mach message
    NSMutableArray* candidateAudioProcs = nil;
    
    //itersection set
    NSMutableSet* intersection = nil;
    
    //pid of coreaudio process
    pid_t coreAudio = 0;
    
    //'frontmost' application
    pid_t activeApp = -1;
    
    //alloc array
    newSenders = [NSMutableArray array];
    
    //alloc array
    newUserClients = [NSMutableArray array];
    
    //alloc array
    candidateAudioProcs = [NSMutableArray array];
    
    //sync this logic
    // ->prevent baselining thread from doing anything
    @synchronized(self)
    {
        //find coreaudio
        coreAudio = findProcess(CORE_AUDIO);
        if(0 == coreAudio)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to find coreaudio process");
            
            //bail
            goto bail;
        }
        
        //get procs that currrently have sent Mach msg to core audio
        // ->returns dictionary of process id, and number of mach messages
        currentSenders = [self enumMachSenders:coreAudio];
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %lu current mach senders: %@", (unsigned long)currentSenders.count, currentSenders]);
        #endif
        
        //add new senders or those w/ new mach msgs
        for(NSNumber* processID in currentSenders.allKeys)
        {
            //ignore client/requestor (self)
            if(clientPID == processID.intValue)
            {
                //skip
                continue;
            }
            
            //skip any that don't have new mach message
            if( (nil != self.machSendersAudio[processID]) &&
                ([self.machSendersAudio[processID] intValue] >= [currentSenders[processID] intValue]) )
            {
                //skip
                continue;
            }
            
            //ok new, so add
            [newSenders addObject:processID];
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"new mach senders: %@", newSenders]);
        #endif
        
        //update iVar
        self.machSendersAudio = currentSenders;
        
        //grab current 'IOPMrootDomain/RootDomainUserClient/IOUserClientCreator's
        currentUserClients = [self enumDomainUserClients];
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %lu current i/o registry user clients: %@", (unsigned long)currentUserClients.count, currentUserClients]);
        #endif
        
        //add new user clients
        for(NSNumber* processID in currentUserClients.allKeys)
        {
            //ignore client/requestor (self)
            if(clientPID == processID.intValue)
            {
                //skip
                continue;
            }
            
            //skip any that don't have new mach message
            if( (nil != self.userClients[processID]) &&
                ([self.userClients[processID] intValue] >= [currentUserClients[processID] intValue]) )
            {
                //skip
                continue;
            }
            
            //ok new, so add
            [newUserClients addObject:processID];
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"new user clients: %@", newUserClients]);
        #endif

        //update iVar
        self.userClients = currentUserClients;
        
        //init set for intersection
        intersection = [NSMutableSet setWithArray:newSenders];
        
        //get procs that have sent mach messages *and* have an entry in the i/o registry
        [intersection intersectSet:[NSMutableSet setWithArray:newUserClients]];
        
        //assign
        candidateAudioProcs = [[intersection allObjects] mutableCopy];
        
        //if there aren't any new i/o registy clients might just be siri
        if(0 == candidateAudioProcs.count)
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"no new user clients");
            #endif
            
            //1 new mach msg sender
            // just use that as candidate
            if(1 == newSenders.count)
            {
                //dbg msg
                #ifdef DEBUG
                logMsg(LOG_DEBUG, @"but only found one new mach sender, so using that!");
                #endif
                
                //assign as candidate
                [candidateAudioProcs addObject:newSenders.firstObject];
            }
            
            //more than
            // ->check if any are siri ('assisantd')?
            else
            {
                //check each new ones
                for(NSNumber* newSender in newSenders)
                {
                    //check each
                    if(YES == [SIRI isEqualToString:getProcessPath([newSender intValue])])
                    {
                         //dbg msg
                         #ifdef DEBUG
                         logMsg(LOG_DEBUG, @"found a mach sender that's 'siri' so using that!");
                         #endif
                         
                         //assign as candidate
                         [candidateAudioProcs addObject:newSenders.firstObject];
                         
                         //all set
                         break;
                    }
                }
            }
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %lu candidate audio procs: %@", (unsigned long)candidateAudioProcs.count, candidateAudioProcs]);
        #endif
        
        //only one candidate?
        // ->all set, so assign, then bail here
        if(1 == candidateAudioProcs.count)
        {
            //assign
            audioProcs = candidateAudioProcs;
            
            //bail
            goto bail;
        }
        
        //still none
        // ->add active app as candiate (and sample it, below)
        if(0 == candidateAudioProcs.count)
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"didn't find any candidate audio apps, will grab (and sample) active application");
            #endif
            
            //get active app
            activeApp = frontmostApplication();
            if(-1 != activeApp)
            {
                //dbg msg
                #ifdef DEBUG
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found active application: %d", activeApp]);
                #endif
                
                //add it
                [candidateAudioProcs addObject:[NSNumber numberWithInt:activeApp]];
            }
        }
        
        //got one or more candidate application
        // ->invoke 'sample' to determine which candidate is using CMIO/video inputs
        //   note: will skip FaceTime.app on macOS Sierra, as it doesn't do CMIO stuff directly
        audioProcs = [self sampleCandidates:candidateAudioProcs];
        
    }//sync
    
//bail
bail:
    
    return audioProcs;
}

//get procs that currrently have sent Mach msg to a target process
// ->returns dictionary of process id, and number of mach messages
-(NSMutableDictionary*)enumMachSenders:(pid_t)targetProcess
{
    //senders
    NSMutableDictionary* senders = nil;
    
    //results from 'lsmp' cmd
    NSString* results = nil;
    
    //substrings
    NSArray* subStrings = nil;
    
    //process id
    NSNumber* processID = nil;
    
    //process path
    NSString* processPath = nil;
    
    //alloc
    senders = [NSMutableDictionary dictionary];
    
    //exec 'lsmp' w/ pid of camera asssistant to get mach ports
    results = [[NSString alloc] initWithData:execTask(LSMP, @[@"-p", @(targetProcess).stringValue], YES) encoding:NSUTF8StringEncoding];
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
        
        //ignore target process
        if(targetProcess == processID.intValue)
        {
            //skip
            continue;
        }
        
        //get process path
        // ->skip blank/unknown procs
        processPath = getProcessPath(processID.intValue);
        if( (nil == processPath) ||
            (0 == processPath.length) )
        {
            //skip
            continue;
        }
        
        //ignore apple daemons (that send mach messages, etc)
        if(YES == [ignoredProcs containsObject:processPath])
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

//iterate thru i/o registry to get all RootDomainUserClient under IOPMrootDomain
// ->returns dictionary of process id, and number of user client entries
-(NSMutableDictionary*)enumDomainUserClients
{
    //matching service
    io_service_t matchingService = 0;
    
    //iterator
    io_iterator_t iterator = 0;
    
    //kids
    io_registry_entry_t child = 0;
    
    //array of RootDomainUserClients
    NSMutableDictionary* clients = nil;
    
    //client creator
    CFTypeRef creator = 0;
    
    //for parsing
    NSArray* components = nil;
    
    //process id
    NSNumber* processID = nil;
    
    //alloc
    clients = [NSMutableDictionary dictionary];
    
    //get IOPMrootDomain obj
    matchingService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMrootDomain"));
    if(0 == matchingService)
    {
        //bail
        goto bail;
    }
    
    //get iterator
    if(noErr != IORegistryEntryGetChildIterator(matchingService, kIOServicePlane, &iterator))
    {
        //bail
        goto bail;
    }
    
    //iterator over all children
    // ->store all that have 'IOUserClientCreator'
    while((child = IOIteratorNext(iterator)))
    {
        //try get creator
        creator = IORegistryEntryCreateCFProperty(child, CFSTR("IOUserClientCreator"), kCFAllocatorDefault, 0);
        
        //always release child
        IOObjectRelease(child);
        
        //if couldn't get a creator
        // ->might just not be of RootDomainUserClient, so skip
        if(0 == creator)
        {
            //skip
            continue;
        }
        
        //parse
        components = [(__bridge NSString*)creator componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ,"]];
        
        //extact pid and save
        if(components.count >= 4)
        {
            //grab pid
            // format is: "pid 4781, process"
            processID = [NSNumber numberWithShort:[components[0x1] intValue]];
            if(0 != processID.intValue)
            {
                //add/inc to dictionary
                clients[processID] = @([clients[processID] unsignedIntegerValue] + 1);
            }
        }
        
        //release
        CFRelease(creator);
    }
    
//bail
bail:
    
    //release iterator
    if(0 != iterator)
    {
        //release
        IOObjectRelease(iterator);
    }
    
    //release obj
    if(0 != matchingService)
    {
        //release
        IOObjectRelease(matchingService);
    }
    
    return clients;

}

//invoke 'sample' to confirm candidates are using CMIO/video/av inputs
// note: path audio/vide invoke 'CMIOGraph::DoWork'
-(NSMutableArray*)sampleCandidates:(NSArray*)currentSenders
{
    //av procs
    NSMutableArray* avProcs = nil;
    
    //results from 'sample' cmd
    NSString* results = nil;
    
    //process path
    NSString* processPath = nil;
    
    //alloc
    avProcs = [NSMutableArray array];
    
    //invoke 'sample' on each
    // ->skips FaceTime.app though on macOS Sierra
    for(NSNumber* processID in currentSenders)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"processing %d for sampling", processID.intValue]);
        #endif
        
        //get process path
        // ->skip ones that fail
        processPath = getProcessPath(processID.intValue);
        if( (nil == processPath) ||
            (0 == processPath.length) )
        {
            //next
            continue;
        }
        
        //if we're running on macOS Sierra and there is only 1 candidate proc and its FaceTime
        // ->don't sample, as it does thing wierdly....
        if( (YES == [processPath isEqualToString:FACE_TIME]) &&
            ([getOSVersion() [@"minorVersion"] intValue] >= 12) )
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"not sampling as candidate app is FaceTime on macOS Sierra");
            #endif
            
            //add
            [avProcs addObject:processID];
            
            //next
            continue;
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sampling %d", processID.intValue]);
        #endif
        
        //exec 'sample' to get threads/dylibs
        // ->uses 1.0 seconds for sampling time
        results = [[NSString alloc] initWithData:execTask(SAMPLE, @[processID.stringValue, @"1"], YES) encoding:NSUTF8StringEncoding];
        if( (nil == results) ||
            (0 == results.length) )
        {
            //skip
            continue;
        }
        
        //sampling a process creates a temp file
        //->make sure we delete it this file to clean up ;)
        [self deleteSampleFile:processPath];
        
        //for now, just check for 'CMIOGraph::DoWork'
        // ->note: both audio/video invoke this, so this method works for both!
        if(YES != [results containsString:@"CMIOGraph::DoWork"])
        {
            //skip
            continue;
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"processing %d for has 'CMIOGraph::DoWork', as adding to list of candidates", processID.intValue]);
        #endif
        
        //looks like a av proc!
        [avProcs addObject:processID];
    }
    
    return avProcs;
}

//'sample' binary creates a file
// ->this looks for that file and deletes it
-(void)deleteSampleFile:(NSString*)processPath
{
    //error
    NSError* error = nil;
    
    //files
    NSArray* files = nil;
    
    //grab all files in /tmp
    files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/tmp/" error:&error];
    if(nil != error)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to enumerate files in /tmp, %@", error]);
        
        //bail
        goto bail;
    }
    
    //find/delete file
    for(NSString* file in files)
    {
        //skip non-sample files
        if(YES != [file hasSuffix:@".sample.txt"])
        {
            //skip
            continue;
        }
        
        //ignore files that don't contain process name
        if(YES != [file containsString:[processPath lastPathComponent]])
        {
            //skip
            continue;
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"deleting sample file: %@", file]);
        #endif
        
        //delete
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:[@"/tmp" stringByAppendingPathComponent:file] error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete %@ (%@)", file, error]);
            
            //bail
            goto bail;
        }
    
    }//all files
    
//bail
bail:
    
    
    return;
}

//set status of video
// ->extra logic is executed to 'refresh' iVars when video is disabled
-(void)updateVideoStatus:(BOOL)isEnabled
{
    //camera assistant
    pid_t cameraAssistant = 0;
    
    //sync
    @synchronized(self)
    {
        //set
        self.videoActive = isEnabled;
        
        //when video disabled
        // ->re-enumerate mach senders
        if(YES != isEnabled)
        {
            //first, look for 'VDCAssistant'
            cameraAssistant = findProcess(VDC_ASSISTANT);
            if(0 == cameraAssistant)
            {
                //look for 'AppleCameraAssistant'
                cameraAssistant = findProcess(APPLE_CAMERA_ASSISTANT);
            }
            
            //sanity check
            if(0 == cameraAssistant)
            {
                //err msg
                logMsg(LOG_ERR, @"failed to find VDCAssistant/AppleCameraAssistant process");
                
                //bail
                goto bail;
            }
            
            //enumerate mach senders
            self.machSendersVideo = [self enumMachSenders:cameraAssistant];
        }
        
    }//sync
    
//bail
bail:
    
    return;
}

//set status of audio
// ->extra logic is executed to 'refresh' iVars when audio is disabled
-(void)updateAudioStatus:(BOOL)isEnabled
{
    //sync
    @synchronized(self)
    {
        //set
        self.audioActive = isEnabled;
        
        //when audio disabled
        // ->re-enumerate mach senders & i/o registry user clients
        if(YES != isEnabled)
        {
            //enumerate mach senders
            self.machSendersAudio = [self enumMachSenders:findProcess(CORE_AUDIO)];
            
            //enumerate i/o registry user clients
            self.userClients = [self enumDomainUserClients];
        }
    }
    
    return;
}

@end


