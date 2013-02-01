
#import "AudioToolbox/AudioToolbox.h"
#import <Foundation/Foundation.h>
#import "IAudioUnit.h"

@interface AudioChain : NSObject

@property NSArray *units;

+ (AudioChain *) create:(NSArray*)units;
- (AudioChain *) connect:(IAudioUnit *)input with:(IAudioUnit *)output on:(int)channel;
- (AudioChain *) disconnect:(IAudioUnit *)input with:(IAudioUnit *)output;

@end
