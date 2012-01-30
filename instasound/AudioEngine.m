#import "AudioToolbox/AudioToolbox.h"
#import "AVFoundation/AVFoundation.h"
#import "AudioPreset.h"

#define WAV_HEADER_LEN 44

#define WRITE_4CHARS(buffer, index, a, b, c, d) buffer[index] = a; buffer[index + 1] = b; buffer[index + 2] = c; buffer[index + 3] = d;


#define WRITE_INT16(buffer, index, value) OSWriteBigInt16(buffer, index, value)
#define WRITE_INT32(buffer, index, value) OSWriteBigInt32(buffer, index, value)


int outputChannel = 0; // because it looks most like the "O" in I/O
int inputChannel = 1;  // because it looks most like the "I" in I/O

int initAudioEngine();

Float32 audioBuffer[32 * 1024 * 1024];

int audioBufferLen = 0;

AudioUnit ioUnit;
AudioUnit mixerUnit;
AudioUnit mixer2Unit;
AudioUnit mixer3Unit;
AudioUnit distortionUnit;

AUGraph graph;

AUNode ioNode;

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


Float32 *getAudioBuffer()
{
    return audioBuffer;
}

int getAudioBufferLength()
{
    return audioBufferLen;
}

static void convertToSInt16(Float32 *input, SInt16 *output, int length)
{
    for (int i = 0; i < length; i++)
    {
        WRITE_INT16(output, i * 2, (SInt16) (input[i] * 32768));
    }
}

NSData *getAudioData(int offset, int length)
{
    int bytes = length * 2;
    UInt8 *buffer = malloc(WAV_HEADER_LEN + bytes);
    
    WRITE_4CHARS(buffer, 0, 'R', 'I', 'F', 'F');
    WRITE_INT32(buffer, 4, bytes + WAV_HEADER_LEN - 8); // File length - 8
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
            length:bytes
            freeWhenDone:TRUE];
}


static OSStatus renderCallback (void *inRefCon,
                                AudioUnitRenderActionFlags 	*ioActionFlags,
                                const AudioTimeStamp		*inTimeStamp,
                                UInt32 						inBusNumber,
                                UInt32 						inNumberFrames,
                                AudioBufferList				*ioData)
{
    AudioUnit *unit = (AudioUnit *)inRefCon;

	OSStatus renderErr;

    renderErr = AudioUnitRender(*unit, ioActionFlags,
								inTimeStamp, 0, inNumberFrames, ioData);
	if (renderErr < 0) {
		return renderErr;
	}

    SInt32 *data = (SInt32 *) ioData->mBuffers[0].mData; // left channel

    for (int i = 0; i < inNumberFrames; i++)
    {
        audioBuffer[audioBufferLen + i] = (data[i] >> 9) / 32512.0;
    }

    audioBufferLen += inNumberFrames;

    return noErr;	// return with samples in iOdata
}

static void initDescriptions()
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

static OSStatus initAudioSession()
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
        NSLog (@"Error setting audio session category.");
        return 1;
    }

    if (![audioSession inputIsAvailable]) {
        NSLog(@"input device is not available");
        return 1;
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

    return noErr;
}

static OSStatus initAudioGraph()
{
    OSStatus result = noErr;

    result = NewAUGraph(&graph);

    result = AUGraphAddNode(graph, &io_desc, &ioNode);
    result = AUGraphAddNode(graph, &mixer_desc, &mixerNode);
    result = AUGraphAddNode(graph, &mixer_desc, &mixer2Node);
    result = AUGraphAddNode(graph, &mixer_desc, &mixer3Node);
    result = AUGraphAddNode(graph, &distortion_desc, &distortionNode);
    
    result = AUGraphOpen(graph);
    result = AUGraphNodeInfo(graph, ioNode, NULL, &ioUnit);
    result = AUGraphNodeInfo(graph, mixerNode, NULL, &mixerUnit);
    result = AUGraphNodeInfo(graph, mixer2Node, NULL, &mixer2Unit);
    result = AUGraphNodeInfo(graph, distortionNode, NULL, &distortionUnit);

    return result;
}

OSStatus initAudioUnits()
{
    
    UInt32 enableInput = 1;
    OSStatus result = noErr;

    result = AudioUnitSetProperty(ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  1,
                                  &enableInput,
                                  sizeof(enableInput));


    UInt32 asbdSize = sizeof(AudioStreamBasicDescription);
    memset (&ioFormat, 0, sizeof (ioFormat));
    
    result = AudioUnitGetProperty(distortionUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &ioFormat,
                                  &asbdSize);
    
    result = AudioUnitSetProperty(mixerUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  &ioFormat,
                                  sizeof(ioFormat));

    if (result != 0) {NSLog(@"FAIL: %ld", result);}

    result = AudioUnitSetProperty(mixer2Unit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &ioFormat,
                                  sizeof(ioFormat));
    
    UInt32 busCount = 6;
    
    result = AudioUnitSetProperty(mixer2Unit,
                                  kAudioUnitProperty_ElementCount,
                                  kAudioUnitScope_Input,
                                  0,
                                  &busCount,
                                  sizeof (busCount));

    return result;
}

static AudioPreset *createPreset()
{
    return [[AudioPreset alloc] create:graph];
}

static void resetGraph()
{
    AUGraphClearConnections(graph);
    AUGraphConnectNodeInput(graph, ioNode, inputChannel, mixerNode, 0);
    AUGraphConnectNodeInput(graph, mixer3Node, 0, ioNode, outputChannel);
    
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc = &renderCallback;
    renderCallbackStruct.inputProcRefCon = &mixer2Unit;
    AUGraphSetNodeInputCallback(graph, mixer3Node, 0, &renderCallbackStruct);
}

static Boolean connectPreset(AudioPreset *preset, int bus)
{
    if (preset.enabled == YES) {
        [preset connect:mixerNode with:mixer2Node on:bus];    
    }
    
    return preset.enabled;
}

static void togglePreset(AudioPreset *preset)
{
    preset1.enabled = NO;
    preset2.enabled = NO;
    preset3.enabled = NO;
    preset4.enabled = NO;
    preset5.enabled = NO;

    preset.enabled = YES;
    
    resetGraph();
    
    connectPreset(preset1, 1);
    connectPreset(preset2, 2);
    connectPreset(preset3, 3);
    connectPreset(preset4, 4);
    connectPreset(preset5, 5);

    if (!preset1.enabled && !preset2.enabled && !preset3.enabled && !preset4.enabled && !preset5.enabled) {
        AUGraphConnectNodeInput(graph, mixerNode, 0, mixer2Node, 0);
    }

    Boolean isUpdated = NO;
    AUGraphUpdate(graph, &isUpdated);
}

static void initPresets()
{   
    preset1 = createPreset();

    [ preset1 bandpass:kBandpassParam_CenterFrequency            to:2000    ];
    [ preset1 bandpass:kBandpassParam_Bandwidth                  to:100     ];

    [ preset1 compression:kDynamicsProcessorParam_ExpansionRatio to:50      ];
    [ preset1 compression:kDynamicsProcessorParam_Threshold      to:-40     ];
    [ preset1 compression:kDynamicsProcessorParam_MasterGain     to:15      ];
    [ preset1 compression:kDynamicsProcessorParam_AttackTime     to:0.0002  ];
    [ preset1 compression:kDynamicsProcessorParam_HeadRoom       to:6       ];
    
    [ preset1 distortion:kDistortionParam_FinalMix               to:50      ];

    [preset1 enableBandpass     ];
    [preset1 enableCompression  ];    
    [preset1 enableDistortion   ];
    
    preset2 = createPreset();

    [ preset2 reverb:kReverb2Param_DecayTimeAtNyquist            to:1.5     ];
    [ preset2 reverb:kReverb2Param_DecayTimeAt0Hz                to:2.5     ];
    [ preset2 reverb:kReverb2Param_DryWetMix                     to:20      ];
    [ preset2 reverb:kReverb2Param_RandomizeReflections          to:100     ];

    [ preset2 enableReverb ];
    
    preset3 = createPreset(); // temp
    
    [ preset3 reverb:kReverb2Param_DecayTimeAtNyquist            to:.66     ];
    [ preset3 reverb:kReverb2Param_DecayTimeAt0Hz                to:1       ];
    [ preset3 reverb:kReverb2Param_DryWetMix                     to:40      ];
    [ preset3 reverb:kReverb2Param_RandomizeReflections          to:1000    ];
    [ preset3 reverb:kReverb2Param_Gain                          to:2       ];
    
    [ preset3 enableReverb ];

    preset4 = createPreset(); // temp
    
    [ preset4 reverb:kReverb2Param_DecayTimeAtNyquist            to:.66     ];
    [ preset4 reverb:kReverb2Param_DecayTimeAt0Hz                to:1       ];
    [ preset4 reverb:kReverb2Param_DryWetMix                     to:60      ];
    [ preset4 reverb:kReverb2Param_RandomizeReflections          to:1000    ];
    [ preset4 reverb:kReverb2Param_Gain                          to:2       ];

    [ preset4 enableReverb ];

    preset5 = createPreset(); // temp
    
    [ preset5 reverb:kReverb2Param_DecayTimeAtNyquist            to:.66     ];
    [ preset5 reverb:kReverb2Param_DecayTimeAt0Hz                to:1       ];
    [ preset5 reverb:kReverb2Param_DryWetMix                     to:100     ];
    [ preset5 reverb:kReverb2Param_RandomizeReflections          to:1000    ];
    [ preset5 reverb:kReverb2Param_Gain                          to:2       ];
    
    [ preset5 enableReverb ];
}

void toggleEffect1()
{
    togglePreset(preset1);
}

void toggleEffect2()
{
    togglePreset(preset2);
}

void toggleEffect3()
{
    togglePreset(preset3);    
}

void toggleEffect4()
{
    togglePreset(preset4);
}

void toggleEffect5()
{
    togglePreset(preset5);
}

int initAudioEngine()
{
    OSStatus result = noErr;

    initDescriptions();

    result = initAudioSession();
    result = initAudioGraph();
    result = initAudioUnits();
    
    initPresets();

    resetGraph();
    AUGraphConnectNodeInput(graph, mixerNode, 0, mixer2Node, 0);
    
    result = AUGraphInitialize(graph);

    CAShow(graph);

    if (result == 0) {
        NSLog(@"AUDIO ENGINE INIT SUCCEEDED");
    }
    else {
        NSLog(@"AUDIO ENGINE INIT FAILED: %ld", result);
        return result;
    }

    AUGraphStart(graph);
    
    // enableTelephone();

    return result;
}

