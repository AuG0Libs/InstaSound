#import "AudioToolbox/AudioToolbox.h"
#import "AVFoundation/AVFoundation.h"
#import "IAudioUnit.h"
#include "errors.h"

@implementation IAudioUnit

+ (IAudioUnit *) mixer:(OSType)subType
{
    return [[[IAudioUnit alloc] init] withComponent:kAudioUnitType_Mixer subType:subType];
}

+ (IAudioUnit *) output:(OSType)subType
{
    return [[[IAudioUnit alloc] init] withComponent:kAudioUnitType_Output subType:subType];
}

+ (IAudioUnit *) effect:(OSType)subType
{
    return [[[IAudioUnit alloc] init] withComponent:kAudioUnitType_Effect subType:subType];
}

+ (IAudioUnit *)dynamicsProcessor
{
    return [self effect:kAudioUnitSubType_DynamicsProcessor];
}

+ (IAudioUnit *)reverb2
{
    return [self effect:kAudioUnitSubType_Reverb2];
}

+ (IAudioUnit *)bandPassFilter
{
    return [self effect:kAudioUnitSubType_BandPassFilter];
}

+ (IAudioUnit *)highShelfFilter
{
    return [self effect:kAudioUnitSubType_HighShelfFilter];
}

+ (IAudioUnit *)distortion
{
    return [self effect:kAudioUnitSubType_Distortion];
}

- (id)init
{
    self = [super init];
    
    if (self) {
        componentInitialized = false;
    }
    
    return self;
}

- (AUGraph)getGraph
{
    if (graph == NULL) {
        [NSException raise:@"IAudioUnitError" format:@"Node not in Graph"];
    }
    
    return graph;
}

- (IAudioUnit *) addNodeTo:(AUGraph)_graph
{
    [self checkComponentInitialized];
    graph = _graph;
    CheckError(AUGraphAddNode(_graph, &_component, &_node), "addNodeTo");
    return self;
}

- (AudioUnit) getUnit
{
    AudioUnit unit;
    CheckError(AUGraphNodeInfo([self getGraph], _node, NULL, &unit), "getUnit");
    return unit;
}

- (void)checkComponentInitialized
{
    if (!componentInitialized) {
        [NSException raise:@"IAudioUnitError" format:@"Component not initialized"];
    }
}

- (IAudioUnit *) enableIO:(AudioUnitElement)element
{
    UInt32 value = 1;
    CheckError(AudioUnitSetProperty([self getUnit],
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Input,
                                    element,
                                    &value,
                                    sizeof(value)), "enableIO");
    return self;
}

- (IAudioUnit *) inputCount:(int)count
{
    UInt32 value = count;
    CheckError(AudioUnitSetProperty([self getUnit],
                                    kAudioUnitProperty_ElementCount,
                                    kAudioUnitScope_Input,
                                    0,
                                    &value,
                                    sizeof (value)), "inputCount");
    
    return self;
}
    
- (IAudioUnit *) param: (AudioUnitParameterID)type to:(AudioUnitParameterValue) value
{
    CheckError(AudioUnitSetParameter([self getUnit], type, kAudioUnitScope_Global, 0, value, 0), "setParameter");
    return self;
}

- (IAudioUnit *) connectTo:(IAudioUnit*)destination from:(int)from to:(int)to;
{
    CheckError(AUGraphConnectNodeInput([self getGraph], _node, from, destination.node, to), "connect");
    return self;
}

- (IAudioUnit *) disconnectFrom:(IAudioUnit*)destination
{
    CheckError(AUGraphDisconnectNodeInput([self getGraph], _node, destination.node), "disconnect");
    return self;
}

- (IAudioUnit *) withComponent:(OSType)type subType:(OSType)subType
{
    _component.componentType                    = type;
    _component.componentSubType                 = subType;
    _component.componentFlags                   = 0;
    _component.componentFlagsMask               = 0;
    _component.componentManufacturer            = kAudioUnitManufacturer_Apple;
    
    componentInitialized = true;
    
    return self;
    
}

- (IAudioUnit *) inputFormat:(AudioUnitElement)element
{
    _inFormat.mSampleRate = 44100;
    _inFormat.mFormatID = 'lpcm';
    _inFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    _inFormat.mBytesPerPacket = 4;
    _inFormat.mFramesPerPacket = 1;
    _inFormat.mBytesPerFrame = 4;
    _inFormat.mChannelsPerFrame = 2;
    _inFormat.mBitsPerChannel = 32;

    CheckError(AudioUnitSetProperty([self getUnit],
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  element,
                                  &_inFormat,
                                  sizeof(_inFormat)), "setInputFormat");
    
    return self;
}


- (IAudioUnit *) outputFormat:(AudioUnitElement)element
{
    _outFormat.mSampleRate = 44100;
    _outFormat.mFormatID = 'lpcm';
    _outFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    _outFormat.mBytesPerPacket = 4;
    _outFormat.mFramesPerPacket = 1;
    _outFormat.mBytesPerFrame = 4;
    _outFormat.mChannelsPerFrame = 2;
    _outFormat.mBitsPerChannel = 32;
    
    CheckError(AudioUnitSetProperty([self getUnit],
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output,
                                    element,
                                    &_outFormat,
                                    sizeof(_outFormat)), "setOutputFormat");
    
    return self;
}
@end


