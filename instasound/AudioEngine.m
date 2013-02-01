#import "AudioEngine.h"
#include "errors.h"

#define WAV_HEADER_LEN 44

#define WRITE_4CHARS(buffer, index, a, b, c, d) buffer[index] = a; buffer[index + 1] = b; buffer[index + 2] = c; buffer[index + 3] = d;

#define WRITE_INT16(buffer, index, value) OSWriteLittleInt16(buffer, index, value)
#define WRITE_INT32(buffer, index, value) OSWriteLittleInt32(buffer, index, value)

static void convertToSInt16(Float32 *input, SInt16 *output, int length)
{
    for (int i = 0; i < length; i++)
    {
        WRITE_INT16(output, i * 2, (SInt16) (input[i] * 32768));
    }
}

static void printASBD(AudioStreamBasicDescription asbd) {
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig (asbd.mFormatID);
    bcopy (&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
 
    NSLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    NSLog (@"  Format ID:           %10s",    formatIDString);
    NSLog (@"  Format Flags:        %10ld",    asbd.mFormatFlags);
    NSLog (@"  Bytes per Packet:    %10ld",    asbd.mBytesPerPacket);
    NSLog (@"  Frames per Packet:   %10ld",    asbd.mFramesPerPacket);
    NSLog (@"  Bytes per Frame:     %10ld",    asbd.mBytesPerFrame);
    NSLog (@"  Channels per Frame:  %10ld",    asbd.mChannelsPerFrame);
    NSLog (@"  Bits per Channel:    %10ld",    asbd.mBitsPerChannel);
}

@implementation AudioEngine

- (Float32*) getBuffer
{
    return audioBuffer;
}

- (int) getBufferLength
{
    return audioBufferLen;
}

- (NSData *) getAudioData: (int)offset withLength:(int)length
{
    int bytes = length * 2;
    UInt8 *buffer = malloc(WAV_HEADER_LEN + bytes);

    WRITE_4CHARS(buffer, 0, 'R', 'I', 'F', 'F');
    WRITE_INT32(buffer, 4, WAV_HEADER_LEN + bytes - 8); // File length - 8
    WRITE_4CHARS(buffer, 8, 'W', 'A', 'V', 'E');
    WRITE_4CHARS(buffer, 12, 'f', 'm', 't', ' ');
    WRITE_INT32(buffer, 16, 16); // Length of fmt data
    WRITE_INT16(buffer, 20, 1); // Type
    WRITE_INT16(buffer, 22, 1); // Channels
    WRITE_INT32(buffer, 24, 44100); // Samples per second
    WRITE_INT32(buffer, 28, 44100 * 2); // Bytes per second
    WRITE_INT16(buffer, 32, 2); //  ((<bits/sample>+7) / 8)
    WRITE_INT16(buffer, 34, 16); // Bits per sample
    WRITE_4CHARS(buffer, 36, 'd', 'a', 't', 'a');
    WRITE_INT32(buffer, 40, bytes); // Data length

    convertToSInt16(audioBuffer + offset, (SInt16 *) (buffer + WAV_HEADER_LEN), length);

    return [[NSData alloc]
            initWithBytesNoCopy:(void *)buffer
            length:WAV_HEADER_LEN + bytes
            freeWhenDone:TRUE];
}


static OSStatus renderCallback (void *inRefCon,
                                AudioUnitRenderActionFlags 	*ioActionFlags,
                                const AudioTimeStamp		*inTimeStamp,
                                UInt32 						inBusNumber,
                                UInt32 						inNumberFrames,
                                AudioBufferList				*ioData)
{
    AudioEngine *engine = (__bridge AudioEngine *)inRefCon;
    Float32 *audioBuffer = engine->audioBuffer;
    int audioBufferLen = engine->audioBufferLen;

    OSStatus status = AudioUnitRender(engine->renderUnit, ioActionFlags,
                                      inTimeStamp, 0, inNumberFrames, ioData);
    
    if (status < 0) return status;

    SInt32 *data = (SInt32 *) ioData->mBuffers[0].mData; // left channel

    for (int i = 0; i < inNumberFrames; i++)
    {
        audioBuffer[audioBufferLen + i] = (data[i] >> 9) / 32512.0;
    }

    engine->audioBufferLen = (engine->audioBufferLen + inNumberFrames) % sizeof(engine->audioBuffer);

    return noErr;	// return with samples in iOdata
}

- (void) initAudioSession
{
    audioSession = [AVAudioSession sharedInstance];

    // Specify that this object is the delegate of the audio session, so that
    //    this object's endInterruption method will be invoked when needed.
    // [audioSession setDelegate: self];

    // Assign the Playback and Record category to the audio session.
    NSError *audioSessionError = nil;
    [audioSession setCategory: AVAudioSessionCategoryPlayAndRecord
                        error: &audioSessionError];

    if (audioSessionError != nil) {
        [NSException raise:@"AudioEngineError" format:@"Cannot set audio session "];
    }

    if (![audioSession inputIsAvailable]) {
        [NSException raise:@"AudioEngineError" format:@"Input device not available"];
    }

    [audioSession setPreferredHardwareSampleRate: 44100.0
                                           error: &audioSessionError];

    // refer to IOS developer library : Audio Session Programming Guide
    // set preferred buffer duration to 1024 using
    //  try ((buffer size + 1) / sample rate) - due to little arm6 floating point bug?
    // doesn't seem to help - the duration seems to get set to whatever the system wants...

    Float32 currentBufferDuration =  (Float32) (1024.0 / 44100.0);
    UInt32 sss = sizeof(currentBufferDuration);

    AudioSessionSetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration, sizeof(currentBufferDuration), &currentBufferDuration);
    NSLog(@"setting buffer duration to: %f", currentBufferDuration);

    // note: this is where ipod touch (w/o mic) erred out when mic (ie earbud thing) was not plugged - before we added
    // the code above to check for mic available
    // Activate the audio session
    [audioSession setActive: YES
                      error: &audioSessionError];

    if (audioSessionError != nil) {
        NSLog (@"Error activating audio session during initial setup.");

    }

    // find out the current buffer duration
    // to calculate duration use: buffersize / sample rate, eg., 512 / 44100 = .012

    // Obtain the actual buffer duration - this may be necessary to get fft stuff working properly in passthru
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration, &sss, &currentBufferDuration);
    NSLog(@"Actual current hardware io buffer duration: %f ", currentBufferDuration );

    // find out how many input channels are available

    NSInteger numberOfChannels = [audioSession currentHardwareInputNumberOfChannels];
    NSLog(@"number of channels: %d", numberOfChannels );
}

- (void) initPresets
{
    [reverb1 param:kReverb2Param_DecayTimeAtNyquist            to:1.5      ];
    [reverb1 param:kReverb2Param_DecayTimeAt0Hz                to:2.5      ];
    [reverb1 param:kReverb2Param_DryWetMix                     to:33       ];
    [reverb1 param:kReverb2Param_RandomizeReflections          to:100      ];

    [bandpass param:kBandpassParam_CenterFrequency            to:1000     ];
    [bandpass param:kBandpassParam_Bandwidth                  to:200      ];
    [compression1 param:kDynamicsProcessorParam_Threshold      to:-40      ];
    [compression1 param:kDynamicsProcessorParam_MasterGain     to:20       ];

    [highshelf param:kHighShelfParam_Gain                     to:6        ];
    [compression2 param:kDynamicsProcessorParam_Threshold      to:-40      ];
    [compression2 param:kDynamicsProcessorParam_MasterGain     to:12       ];
    [compression2 param:kDynamicsProcessorParam_AttackTime     to:0.0002   ];

    [reverb2 param:kReverb2Param_DecayTimeAtNyquist            to:.66      ];
    [reverb2 param:kReverb2Param_DecayTimeAt0Hz                to:1        ];
    [reverb2 param:kReverb2Param_DryWetMix                     to:60       ];
    [reverb2 param:kReverb2Param_RandomizeReflections          to:1000     ];
    [reverb2 param:kReverb2Param_Gain                          to:2        ];
    
    preset1 = [AudioChain create:@[reverb1]];
    preset2 = [AudioChain create:@[bandpass, compression1]];
    preset3 = [AudioChain create:@[highshelf, compression2]];
    preset4 = [AudioChain create:@[reverb2]];
    
//    [preset5.bandpass setParameter:kBandpassParam_CenterFrequency            to:2000     ];
//    [preset5.bandpass setParameter:kBandpassParam_Bandwidth                  to:100      ];
//    [preset5 distortion:kDistortionParam_FinalMix               to:50       ];
    
    
//    [preset5 enableBandpass];
//    [preset5 enableDistortion];
}

- (void) togglePreset:(AudioChain*)preset
{
    [self resetGraph];
    
    [preset connect:mixer1 with:mixer2 on:0];

    Boolean isUpdated = NO;
    AUGraphUpdate(graph, &isUpdated);
}

- (void) toggleEffect:(int)index
{
    switch(index) {
        case 1: [self togglePreset:preset1]; break;
        case 2: [self togglePreset:preset2]; break;
        case 3: [self togglePreset:preset3]; break;
        case 4: [self togglePreset:preset4]; break;
        case 5: [self togglePreset:preset5]; break;
    }
}

- (void) initGraph
{
    CheckError(NewAUGraph(&graph), "NewAUGraph");
    
    remoteIO     = [[IAudioUnit output:kAudioUnitSubType_RemoteIO] addNodeTo:graph];
    mixer1       = [[IAudioUnit mixer:kAudioUnitSubType_MultiChannelMixer] addNodeTo:graph];
    mixer2       = [[IAudioUnit mixer:kAudioUnitSubType_MultiChannelMixer] addNodeTo:graph];
    mixer3       = [[IAudioUnit mixer:kAudioUnitSubType_MultiChannelMixer] addNodeTo:graph];
    reverb1      = [[IAudioUnit reverb2] addNodeTo:graph];
    reverb2      = [[IAudioUnit reverb2] addNodeTo:graph];
    bandpass     = [[IAudioUnit bandPassFilter] addNodeTo:graph];
    highshelf    = [[IAudioUnit highShelfFilter] addNodeTo:graph];
    compression1 = [[IAudioUnit dynamicsProcessor] addNodeTo:graph];
    compression2 = [[IAudioUnit dynamicsProcessor] addNodeTo:graph];
    
    CheckError(AUGraphOpen(graph), "AUGraphOpen");
    
    [remoteIO enableIO:1];
    [mixer1 outputFormat:0];
    [mixer2 inputFormat:0];
    [mixer3 inputFormat:0];
    
    [self initPresets];
    
    renderUnit = [mixer2 getUnit];
}

- (void) resetGraph
{
    AUGraphClearConnections(graph);
    
    [remoteIO connectTo:mixer1   from:1 to:0];
//    [mixer1   connectTo:mixer2   from:0 to:0];
    [mixer3   connectTo:remoteIO from:0 to:0];
    
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc = &renderCallback;
    renderCallbackStruct.inputProcRefCon = (__bridge void*) self;
    
    AUGraphSetNodeInputCallback(graph, mixer3.node, 0, &renderCallbackStruct);
}

- (AudioEngine*) init
{
    if (self = [super init]) {
        OSStatus result = noErr;
        audioBufferLen = 0;
        
        @try
        {
            [self initAudioSession];
            [self initGraph];
            [self initPresets];
            [self resetGraph];
            
            result = AUGraphInitialize(graph);
            
            if (result != noErr) {
                [NSException raise:@"AudioEngineError" format:@"Failed to initialize graph"];
            }
            
            CAShow(graph);
            
            result = AUGraphStart(graph);
            
            if (result != noErr) {
                [NSException raise:@"AudioEngineError" format:@"Failed to start graph"];
            }
        }
        @catch(NSException* ex)
        {
            NSLog(@"%@", ex.reason);
            NSLog(@"%@", ex.callStackSymbols);
        }
    }

    return self;
}


@end

