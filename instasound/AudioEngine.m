#import "AudioEngine.h"

#define WAV_HEADER_LEN 44

#define WRITE_4CHARS(buffer, index, a, b, c, d) buffer[index] = a; buffer[index + 1] = b; buffer[index + 2] = c; buffer[index + 3] = d;

#define WRITE_INT16(buffer, index, value) OSWriteLittleInt16(buffer, index, value)
#define WRITE_INT32(buffer, index, value) OSWriteLittleInt32(buffer, index, value)

int outputChannel = 0; // because it looks most like the "O" in I/O
int inputChannel = 1;  // because it looks most like the "I" in I/O

static void convertToSInt16(Float32 *input, SInt16 *output, int length)
{
    for (int i = 0; i < length; i++)
    {
        WRITE_INT16(output, i * 2, (SInt16) (input[i] * 32768));
    }
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

	OSStatus renderErr;

    renderErr = AudioUnitRender(engine->mixer2Unit, ioActionFlags,
								inTimeStamp, 0, inNumberFrames, ioData);
	if (renderErr < 0) {
		return renderErr;
	}

    SInt32 *data = (SInt32 *) ioData->mBuffers[0].mData; // left channel

    for (int i = 0; i < inNumberFrames; i++)
    {
        audioBuffer[audioBufferLen + i] = (data[i] >> 9) / 32512.0;
    }

    engine->audioBufferLen = (engine->audioBufferLen + inNumberFrames) % sizeof(engine->audioBuffer);

    return noErr;	// return with samples in iOdata
}

- (void) initDescriptions
{
    io_desc.componentType                       = kAudioUnitType_Output;
    io_desc.componentSubType                    = kAudioUnitSubType_RemoteIO;
    io_desc.componentFlags                      = 0;
    io_desc.componentFlagsMask                  = 0;
    io_desc.componentManufacturer               = kAudioUnitManufacturer_Apple;

    mixer_desc.componentType                    = kAudioUnitType_Mixer;
    mixer_desc.componentSubType                 = kAudioUnitSubType_MultiChannelMixer;
    mixer_desc.componentFlags                   = 0;
    mixer_desc.componentFlagsMask               = 0;
    mixer_desc.componentManufacturer            = kAudioUnitManufacturer_Apple;

    distortion_desc.componentType               = kAudioUnitType_Effect;
    distortion_desc.componentSubType            = kAudioUnitSubType_Distortion;
    distortion_desc.componentFlags              = 0;
    distortion_desc.componentFlagsMask          = 0;
    distortion_desc.componentManufacturer       = kAudioUnitManufacturer_Apple;
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

- (void) initAudioGraph
{
    OSStatus result = noErr;

    result |= NewAUGraph(&graph);

    result |= AUGraphAddNode(graph, &io_desc, &ioNode);
    result |= AUGraphAddNode(graph, &mixer_desc, &mixerNode);
    result |= AUGraphAddNode(graph, &mixer_desc, &mixer2Node);
    result |= AUGraphAddNode(graph, &mixer_desc, &mixer3Node);
    result |= AUGraphAddNode(graph, &distortion_desc, &distortionNode);
    
    result = AUGraphOpen(graph);
    result = AUGraphNodeInfo(graph, ioNode, NULL, &ioUnit);
    result = AUGraphNodeInfo(graph, mixerNode, NULL, &mixerUnit);
    result = AUGraphNodeInfo(graph, mixer2Node, NULL, &mixer2Unit);
    result = AUGraphNodeInfo(graph, distortionNode, NULL, &distortionUnit);

    if (result != noErr) {
        [NSException raise:@"AudioEngineError" format:@"Failed to init audio graph"];

    }
}

- (void) initAudioUnits
{
    UInt32 enableInput = 1;
    OSStatus result = noErr;

    result |= AudioUnitSetProperty(ioUnit,
                                   kAudioOutputUnitProperty_EnableIO,
                                   kAudioUnitScope_Input,
                                   1,
                                   &enableInput,
                                   sizeof(enableInput));




    UInt32 asbdSize = sizeof(AudioStreamBasicDescription);
    memset (&ioFormat, 0, sizeof (ioFormat));

    result |= AudioUnitGetProperty(distortionUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Input,
                                   0,
                                   &ioFormat,
                                   &asbdSize);

    result |= AudioUnitSetProperty(mixerUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Output,
                                   0,
                                   &ioFormat,
                                   sizeof(ioFormat));

    if (result != 0) {NSLog(@"FAIL: %ld", result);}

    result |= AudioUnitSetProperty(mixer2Unit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Input,
                                   0,
                                   &ioFormat,
                                   sizeof(ioFormat));

    UInt32 busCount = 6;

    result |= AudioUnitSetProperty(mixer2Unit,
                                   kAudioUnitProperty_ElementCount,
                                   kAudioUnitScope_Input,
                                   0,
                                   &busCount,
                                   sizeof (busCount));

    if (result != noErr) {
        [NSException raise:@"AudioEngineError" format:@"Failed to init audio units"];
    }
}

- (AudioPreset *) createPreset
{
    return [[AudioPreset alloc] create:graph];
}

- (void) resetGraph
{
    AUGraphClearConnections(graph);
    AUGraphConnectNodeInput(graph, ioNode, inputChannel, mixerNode, 0);
    AUGraphConnectNodeInput(graph, mixer3Node, 0, ioNode, outputChannel);

    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc = &renderCallback;
    renderCallbackStruct.inputProcRefCon = (__bridge void*) self;
    AUGraphSetNodeInputCallback(graph, mixer3Node, 0, &renderCallbackStruct);
}

- (Boolean) connectPreset:(AudioPreset*)preset toBus:(int)bus
{
    if (preset.enabled == YES) {
        [preset connect:mixerNode with:mixer2Node on:bus];
    }

    return preset.enabled;
}

- (void) togglePreset:(AudioPreset*)preset
{
    preset1.enabled = NO;
    preset2.enabled = NO;
    preset3.enabled = NO;
    preset4.enabled = NO;
    preset5.enabled = NO;

    preset.enabled = YES;

    [self resetGraph];

    [self connectPreset:preset1 toBus:1];
    [self connectPreset:preset2 toBus:2];
    [self connectPreset:preset3 toBus:3];
    [self connectPreset:preset4 toBus:4];
    [self connectPreset:preset5 toBus:5];

    if (!preset1.enabled && !preset2.enabled && !preset3.enabled && !preset4.enabled && !preset5.enabled) {
        AUGraphConnectNodeInput(graph, mixerNode, 0, mixer2Node, 0);
    }

    Boolean isUpdated = NO;
    AUGraphUpdate(graph, &isUpdated);
}

- (void) initPresets
{
    preset1 = [self createPreset];

    [preset1 reverb:kReverb2Param_DecayTimeAtNyquist            to:1.5      ];
    [preset1 reverb:kReverb2Param_DecayTimeAt0Hz                to:2.5      ];
    [preset1 reverb:kReverb2Param_DryWetMix                     to:33       ];
    [preset1 reverb:kReverb2Param_RandomizeReflections          to:100      ];

    [preset1 enableReverb];

    preset2 = [self createPreset];

    [preset2 bandpass:kBandpassParam_CenterFrequency            to:1000     ];
    [preset2 bandpass:kBandpassParam_Bandwidth                  to:200      ];
    [preset2 compression:kDynamicsProcessorParam_Threshold      to:-40      ];
    [preset2 compression:kDynamicsProcessorParam_MasterGain     to:20       ];

    [preset2 enableBandpass];
    [preset2 enableCompression];

    preset3 = [self createPreset];

    [preset3 highshelf:kHighShelfParam_Gain                     to:6        ];

    [preset3 compression:kDynamicsProcessorParam_Threshold      to:-40      ];
    [preset3 compression:kDynamicsProcessorParam_MasterGain     to:12       ];
    [preset3 compression:kDynamicsProcessorParam_AttackTime     to:0.0002   ];

    [preset3 enableHighshelf];
    [preset3 enableCompression];

    preset4 = [self createPreset];

    [preset4 reverb:kReverb2Param_DecayTimeAtNyquist            to:.66      ];
    [preset4 reverb:kReverb2Param_DecayTimeAt0Hz                to:1        ];
    [preset4 reverb:kReverb2Param_DryWetMix                     to:60       ];
    [preset4 reverb:kReverb2Param_RandomizeReflections          to:1000     ];
    [preset4 reverb:kReverb2Param_Gain                          to:2        ];

    [preset4 enableReverb];

    preset5 = [self createPreset];

//    [preset5 bandpass:kBandpassParam_CenterFrequency            to:2000     ];
//    [preset5 bandpass:kBandpassParam_Bandwidth                  to:100      ];
//    [preset5 distortion:kDistortionParam_FinalMix               to:50       ];
    
    [preset5 enableFile:@"vinyl" ofType:@"aif" withFormat:ioFormat];
    
//    [preset5 enableBandpass];
//    [preset5 enableDistortion];
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

- (AudioEngine*) init
{
    if (self = [super init]) {
        OSStatus result = noErr;

        audioBufferLen = 0;

        [self initDescriptions];
        [self initAudioSession];
        [self initAudioGraph];
        [self initAudioUnits];

        [self initPresets];

        [self resetGraph];

        AUGraphConnectNodeInput(graph, mixerNode, 0, mixer2Node, 0);

        result |= AUGraphInitialize(graph);

        CAShow(graph);

        result |= AUGraphStart(graph);


        if (result != noErr) {
            [NSException raise:@"AudioEngineError" format:@"Failed to init audio engine"];
        }
    }

    return self;
}


@end

