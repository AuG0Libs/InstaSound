#import "AudioToolbox/AudioToolbox.h"
#import "AVFoundation/AVFoundation.h"
#import "AudioChain.h"

@interface AudioEngine : NSObject {

@private
    Float32 audioBuffer[32 * 1024 * 1024];
    int audioBufferLen;
    
    AUGraph graph;
    
    AudioUnit renderUnit;
    
    IAudioUnit *remoteIO;
    IAudioUnit *mixer1;
    IAudioUnit *mixer2;
    IAudioUnit *mixer3;
    
    AVAudioSession *audioSession;
    
    AudioChain *preset1;
    AudioChain *preset2;
    AudioChain *preset3;
    AudioChain *preset4;
    AudioChain *preset5;
    
    IAudioUnit *reverb1;
    IAudioUnit *reverb2;
    IAudioUnit *bandpass;
    IAudioUnit *highshelf;
    IAudioUnit *compression1;
    IAudioUnit *compression2;
}

- (Float32*) getBuffer;

- (int) getBufferLength;

- (AudioEngine*) init;

- (NSData*) getAudioData: (int)offset withLength:(int)length;

- (void) toggleEffect:(int)index;

@end

