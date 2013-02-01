#import <Foundation/Foundation.h>

#import "AudioToolbox/AudioToolbox.h"

@interface IAudioUnit : NSObject {
    bool componentInitialized;
    AUGraph graph;
}

@property AudioStreamBasicDescription inFormat;
@property AudioStreamBasicDescription outFormat;
@property AudioComponentDescription component;
@property AUNode node;
@property bool enabled;

+ (IAudioUnit *) mixer:(OSType)subType;
+ (IAudioUnit *) output:(OSType)subType;
+ (IAudioUnit *) effect:(OSType)subType;
+ (IAudioUnit *) dynamicsProcessor;
+ (IAudioUnit *) reverb2;
+ (IAudioUnit *) bandPassFilter;
+ (IAudioUnit *) highShelfFilter;
+ (IAudioUnit *) distortion;

- (AUGraph) getGraph;
- (AudioUnit) getUnit;
- (IAudioUnit *) enableIO:(AudioUnitElement)element;
- (IAudioUnit *) param: (AudioUnitParameterID)type to:(AudioUnitParameterValue) value;
- (IAudioUnit *) inputCount:(int)count;
- (IAudioUnit *) inputFormat:(AudioUnitElement)element;
- (IAudioUnit *) outputFormat:(AudioUnitElement)element;
- (IAudioUnit *) addNodeTo:(AUGraph)graph;
- (IAudioUnit *) connectTo:(IAudioUnit*)destination from:(int)from to:(int)to;
- (IAudioUnit *) disconnectFrom:(IAudioUnit*)destination;

@end
