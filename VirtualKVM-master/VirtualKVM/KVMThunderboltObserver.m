#import "KVMThunderboltObserver.h"
#import "KVMSystemProfiler.h"
#import "VirtualKVM-Swift.h"
@import SBObjectiveCWrapper;
@interface KVMThunderboltObserver () <NetworkInterfaceNotifierDelegate>

@property BOOL initialized;
@property BOOL macConnected;
@property NSArray *systemProfilerInformation;
@property (nonatomic, assign) BOOL shouldRepeat;
@property (nonatomic, assign, getter=isThunderboltEnabled) BOOL thunderboltEnabled;
@property (nonatomic, strong) NetworkInterfaceNotifier *networkInterfaceNotifier;

@end


@implementation KVMThunderboltObserver

+ (void)initialize {
  [[Uiltites shared]setupLogging];
}

#pragma mark - Public Interface

- (id)initWithDelegate:(id<KVMThunderBoltObserverDelegate>)delegate {
  self = [super init];
  self.delegate = delegate;
  self.macConnected = NO;
  self.systemProfilerInformation = nil;
  self.networkInterfaceNotifier = [NetworkInterfaceNotifier new];
  return self;
}

- (void)dealloc {
  [[NSWorkspace sharedWorkspace].notificationCenter removeObserver:self name:NSWorkspaceDidWakeNotification object:nil];
  [[NSWorkspace sharedWorkspace].notificationCenter removeObserver:self name:NSWorkspaceScreensDidWakeNotification object:nil];
}

#pragma mark -

- (void)networkInterfaceNotifierDidDetectChanage {
  
  SBLogInfo(@"Network interface change detected");
  [self checkForThunderboltConnection];
}

- (void)startObserving {
  SBLogInfo(@"Start observing thunderbolt connections");
  self.networkInterfaceNotifier.delegate = self;
  [self.networkInterfaceNotifier startObserving];
  [self checkForThunderboltConnection];
  [[NSWorkspace sharedWorkspace].notificationCenter addObserver:self selector:@selector(didWake) name:NSWorkspaceDidWakeNotification object:nil];
  [[NSWorkspace sharedWorkspace].notificationCenter addObserver:self selector:@selector(screenDidWake) name:NSWorkspaceScreensDidWakeNotification object:nil];
}

- (void)screenDidWake {
  
  SBLogInfo(@"Screen did wake");
  [self checkForThunderboltConnection];
}

- (void)didWake {
  
  SBLogInfo(@"Computer did wake");
  [self checkForThunderboltConnection];
}

// Determines if the host has thunderbolt ports
- (BOOL)isThunderboltEnabled {
  
  NSDictionary *profilerResponse = [self systemProfilerThunderboltInfo];
  
  if (profilerResponse.count >= 1) {
    NSArray *items = profilerResponse[@"_items"];
    
    if (!items || items.count == 0) {
      return NO;
    }
    NSString *busName = items[0][@"_name"];
    
    if ([busName isEqualToString:@"thunderbolt_bus"]) {
      return YES;
    }
    return NO;
  }
  
  return NO;
}

- (void)stopObserving {

  SBLogInfo(@"Stop observing thunderbolt connections");
  
  [[NSWorkspace sharedWorkspace].notificationCenter removeObserver:self name:NSWorkspaceDidWakeNotification object:nil];
  [[NSWorkspace sharedWorkspace].notificationCenter removeObserver:self name:NSWorkspaceScreensDidWakeNotification object:nil];
}

- (void)updateSystemProfilerInformation {
  self.systemProfilerInformation = [KVMSystemProfiler dataTypes:@[@"SPDisplaysDataType", @"SPThunderboltDataType"]];
}

- (NSDictionary *)systemProfilerDisplayInfo {
  if (self.systemProfilerInformation == nil) {
    [self updateSystemProfilerInformation];
  }
  
  return self.systemProfilerInformation[0];
}

- (NSString *)systemAssertionInfomation {
  
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath:@"/usr/bin/pmset"];
  [task setArguments:@[@"-g", @"assertions"]];
  
  NSPipe *out = [NSPipe pipe];
  [task setStandardOutput:out];
  
  @try {
    [task launch];
  } @catch (NSException *exception) {
    SBLogWarning(@"Caught exception: %@", exception);
    return nil;
  }
  
  NSFileHandle *read = [out fileHandleForReading];
  NSData *dataRead = [read readDataToEndOfFile];
  
  NSString *string = [[NSString alloc]initWithData:dataRead encoding:NSUTF8StringEncoding];
  
  return string;
}

- (NSDictionary *)systemProfilerThunderboltInfo {
  if (self.systemProfilerInformation == nil) {
    [self updateSystemProfilerInformation];
  }
  
  return self.systemProfilerInformation[1];
}

- (void)checkForThunderboltConnection {
  [[NSOperationQueue mainQueue]addOperationWithBlock:^{
    
    SBLogInfo(@"Checking for thuderbolt connection. \nDisplay Info: %@ \nThunderbolt Info: %@\nPower Assertion Info: %@", [self systemProfilerDisplayInfo], [self systemProfilerThunderboltInfo], [self systemAssertionInfomation]);
    [self updateSystemProfilerInformation];
    
    BOOL previouslyConnected = self.macConnected;
    
    if (self.isThunderboltEnabled) {
      self.macConnected = [self macConnectedViaThunderbolt];
    } else {
      //Starting on macOS 10.1.4 macConnectedViaDisplayPort will return `YES` on iMac's with thunderbolt ports and therefore cause the application to always think that it is in TDM.
      self.macConnected = [self macConnectedViaDisplayPort];
    }
    
    BOOL changed = self.macConnected != previouslyConnected;
    
    if (changed) {
      [self notifyDelegateOfConnectionChange];
    }
    
    if (!self.initialized) {
      self.initialized = YES;
      [self notifyDelegateOfInitialization];
    }
  }];
}

- (void)notifyDelegateOfConnectionChange {
  if (self.macConnected) {
    if (self.delegate && [self.delegate respondsToSelector:@selector(thunderboltObserverDeviceConnected:)]) {
      [self.delegate thunderboltObserverDeviceConnected:self];
    }
  } else {
    if (self.delegate && [self.delegate respondsToSelector:@selector(thunderboltObserverDeviceDisconnected:)]) {
      [self.delegate thunderboltObserverDeviceDisconnected:self];
    }
  }
}

- (void)notifyDelegateOfInitialization {
  if (self.delegate && [self.delegate respondsToSelector:@selector(thunderboltObserver:isInitiallyConnected:)]) {
    [self.delegate thunderboltObserver:self isInitiallyConnected:self.macConnected];
  }
}

- (BOOL)macConnectedViaDisplayPort {
  if ([self isInTargetDisplayMode]) {
    return YES;
  }
  
  NSDictionary *plist = [self systemProfilerDisplayInfo];
  
  NSArray *gpus = plist[@"_items"];
  
  for (NSDictionary *gpu in gpus) {
    NSArray *displays = gpu[@"spdisplays_ndrvs"];
    
    for (NSDictionary *display in displays) {
      if ([display[@"spdisplays_connection_type"] isEqualToString:@"spdisplays_displayport_dongletype_dp"]) {
        if ([display[@"_spdisplays_display-vendor-id"] isEqualToString:@"610"]) {
          return YES;
        }
      }
    }
  }
  
  return NO;
}

- (BOOL)isInTargetDisplayMode {
  NSString *assertionString = [self systemAssertionInfomation];
  //The Display Port daemon. If this isn't holding an assertion then the iMac isn't in TDM.
  return [assertionString containsString:@"com.apple.dpd"];
}

- (BOOL)macConnectedViaThunderbolt {
  NSDictionary *plist = [self systemProfilerThunderboltInfo];
  
  NSArray *devices = plist[@"_items"][0][@"_items"];
  
  for (NSDictionary *device in devices) {
    if ([device[@"vendor_id_key"] isEqualToString:@"0xA27"]) {
      return YES;
    }
  }
  
  return NO;
}

@end
