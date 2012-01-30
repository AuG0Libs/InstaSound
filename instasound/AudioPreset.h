
#import "AudioToolbox/AudioToolbox.h"
#import <Foundation/Foundation.h>

@interface AudioPreset : NSObject
{
    AUGraph graph;
    Boolean enabled;
    
    AudioComponentDescription distortion_desc;
    AudioComponentDescription reverb_desc;
    AudioComponentDescription compression_desc;
    AudioComponentDescription bandpass_desc;
    AudioComponentDescription fileplayer_desc;
    
    AUNode distortionNode;
    AUNode reverbNode;
    AUNode compressionNode;
    AUNode bandpassNode;
    AUNode fileplayerNode;
    
    AudioUnit distortionUnit;
    AudioUnit reverbUnit;
    AudioUnit compressionUnit;
    AudioUnit bandpassUnit;
    AudioUnit fileplayerUnit;
    
    AUNode nodes[16];
    int nodeCount;
}

@property (atomic) Boolean enabled;

- (void) initDescriptions;

- (AudioPreset *) create:(AUGraph) graph;
- (AudioPreset *) connect:(AUNode)input with:(AUNode)output on:(int)channel;
- (void) enableDistortion;
- (void) enableReverb;
- (void) enableBandpass;
- (void) enableCompression;
- (void) enableFile: (NSString *)file ofType:(NSString *)type withFormat:(AudioStreamBasicDescription)ioFormat;

- (id) distortion: (AudioUnitParameterID)type to:(AudioUnitParameterValue) value;
- (id) reverb: (AudioUnitParameterID)type to:(AudioUnitParameterValue) value;
- (id) compression: (AudioUnitParameterID)type to:(AudioUnitParameterValue) value;
- (id) bandpass: (AudioUnitParameterID)type to:(AudioUnitParameterValue) value;

@end
