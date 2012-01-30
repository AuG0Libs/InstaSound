#import "AudioToolbox/AudioToolbox.h"
#import "AVFoundation/AVFoundation.h"

int initAudioEngine();

Float32 audioBuffer[32 * 1024 * 1024];

int audioBufferLen = 0;

AudioUnit mixerUnit;
AudioUnit mixer2Unit;    
AudioUnit mixer3Unit;    
AudioUnit ioUnit;
AudioUnit distortionUnit;
AudioUnit output;
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
        output[i] = (SInt16) (input[i] / 32768);
    }
}

#define WAV_HEADER_LEN 44

#define WRITE_UINT8(buffer, index, value) ((UInt8 *)buffer)[index] = value
#define WRITE_UINT16(buffer, index, value) ((UInt16 *)buffer)[index / sizeof(UInt16)] = value
#define WRITE_UINT32(buffer, index, value) ((UInt32 *)buffer)[index / sizeof(UInt32)] = value
#define WRITE_4CHARS(buffer, index, a, b, c, d) buffer[index] = a; buffer[index + 1] = b; buffer[index + 2] = c; buffer[index + 3] = d;


NSData *getAudioData(int offset, int length)
{
    UInt8 *buffer = malloc(WAV_HEADER_LEN + length * sizeof(SInt16));
    
    WRITE_4CHARS(buffer, 0, 'R', 'I', 'F', 'F');
    WRITE_UINT32(buffer, 4, audioBufferLen * 2 - 36); // File length - 8
    WRITE_4CHARS(buffer, 8, 'W', 'A', 'V', 'E');
    WRITE_4CHARS(buffer, 16, 'f', 'm', 't', 0);
    WRITE_UINT16(buffer, 20, 1); // Type
    WRITE_UINT16(buffer, 22, 1); // Channels
    WRITE_UINT32(buffer, 24, 44100); // Samples per second
    WRITE_UINT32(buffer, 28, 44100 * 2); // Bytes per second
    WRITE_UINT16(buffer, 32, 2); //  ((<bits/sample>+7) / 8)
    WRITE_UINT16(buffer, 34, 16); // Bits per sample
    WRITE_4CHARS(buffer, 36, 'd', 'a', 't', 'a');
    WRITE_UINT32(buffer, 40, audioBufferLen); // Data length

    convertToSInt16(audioBuffer + offset, (SInt16 *) (buffer + WAV_HEADER_LEN), length); 
    
    return [[NSData alloc] 
            initWithBytesNoCopy:(void *)buffer
            length:audioBufferLen 
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
    io_desc.componentType               = kAudioUnitType_Output;
    io_desc.componentSubType            = kAudioUnitSubType_RemoteIO;
    io_desc.componentFlags              = 0;
    io_desc.componentFlagsMask          = 0;
    io_desc.componentManufacturer       = kAudioUnitManufacturer_Apple;
    
    mixer_desc.componentType            = kAudioUnitType_Mixer;
    mixer_desc.componentSubType         = kAudioUnitSubType_MultiChannelMixer;
    mixer_desc.componentFlags           = 0;
    mixer_desc.componentFlagsMask       = 0;
    mixer_desc.componentManufacturer    = kAudioUnitManufacturer_Apple;
    
    
    distortion_desc.componentType            = kAudioUnitType_Effect;
    distortion_desc.componentSubType         = kAudioUnitSubType_Distortion;
    distortion_desc.componentFlags           = 0;
    distortion_desc.componentFlagsMask       = 0;
    distortion_desc.componentManufacturer    = kAudioUnitManufacturer_Apple;
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
    
    int outputChannel = 0;
    int inputChannel = 1;
    
    result = AUGraphConnectNodeInput(graph, ioNode, inputChannel, mixerNode, 0);
    result = AUGraphConnectNodeInput(graph, mixerNode, 0, distortionNode, 0);
    result = AUGraphConnectNodeInput(graph, distortionNode, 0, mixer2Node, 0);
    result = AUGraphConnectNodeInput(graph, mixer3Node, 0, ioNode, outputChannel);
    
    result = AUGraphOpen(graph);
    result = AUGraphNodeInfo(graph, ioNode, NULL, &ioUnit);
    result = AUGraphNodeInfo(graph, mixerNode, NULL, &mixerUnit);
    result = AUGraphNodeInfo(graph, mixer2Node, NULL, &mixer2Unit);
    result = AUGraphNodeInfo(graph, distortionNode, NULL, &distortionUnit);
    
    
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc = &renderCallback;
    renderCallbackStruct.inputProcRefCon = &mixer2Unit;
    result = AUGraphSetNodeInputCallback(graph, mixer3Node, 0, &renderCallbackStruct);
    
    return result;
}

static OSStatus initAudioUnits()
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

    return result;
}

int initAudioEngine()
{ 
    OSStatus result = noErr;
    
    initDescriptions();
    
    result = initAudioSession();
    result = initAudioGraph();
    result = initAudioUnits();
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
    
    return result;
}
