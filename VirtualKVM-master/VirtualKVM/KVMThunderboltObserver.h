#import <Foundation/Foundation.h>

@protocol KVMThunderBoltObserverDelegate;

@interface KVMThunderboltObserver : NSObject

@property (nonatomic, strong) id<KVMThunderBoltObserverDelegate> delegate;
@property (readonly) BOOL macConnected;
@property (nonatomic, assign, readonly, getter=isThunderboltEnabled) BOOL thunderboltEnabled;

- (id)initWithDelegate:(id<KVMThunderBoltObserverDelegate>)delegate;
- (void)startObserving;
- (void)stopObserving;
- (BOOL)isInTargetDisplayMode;
- (NSString *)systemAssertionInfomation;

@end

@protocol KVMThunderBoltObserverDelegate <NSObject>

@optional
- (void)thunderboltObserver:(KVMThunderboltObserver *)observer isInitiallyConnected:(BOOL)connected;
- (void)thunderboltObserverDeviceConnected:(KVMThunderboltObserver *)observer;
- (void)thunderboltObserverDeviceDisconnected:(KVMThunderboltObserver *)observer;

@end
