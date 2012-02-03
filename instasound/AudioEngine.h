#import "AudioToolbox/AudioToolbox.h"
#import "AVFoundation/AVFoundation.h"
#import "AudioPreset.h"

@interface AudioEngine : NSObject {

@private
    Float32 audioBuffer[32 * 1024 * 1024];
    int audioBufferLen;
    
    AUGraph graph;
    
    AUNode ioNode;
    
    AudioUnit ioUnit;
    AudioUnit mixerUnit;
    AudioUnit mixer2Unit;
    AudioUnit mixer3Unit;
    AudioUnit distortionUnit;
    
    AUNode mixerNode;
    AUNode mixer2Node;
    AUNode mixer3Node;
    AUNode distortionNode;
    
    AudioComponentDescription io_desc;
    AudioComponentDescription mixer_desc;
    AudioComponentDescription distortion_desc;
    
    AVAudioSession *audioSession;
    AudioStreamBasicDescription	ioFormat;
    
    AudioPreset *preset1;
    AudioPreset *preset2;
    AudioPreset *preset3;
    AudioPreset *preset4;
    AudioPreset *preset5;
}

- (Float32*) getBuffer;

- (int) getBufferLength;

- (AudioEngine*) init;

- (void) initAudioUnits;
- (void) initAudioGraph;
- (void) initDescriptions;

- (NSData*) getAudioData: (int)offset withLength:(int)length;

- (void) toggleEffect:(int)index;

@end

