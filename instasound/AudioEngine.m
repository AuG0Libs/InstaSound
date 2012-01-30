#import "AudioToolbox/AudioToolbox.h"
#import "AVFoundation/AVFoundation.h"

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
AudioUnit reverbUnit;
AudioUnit compressionUnit;
AudioUnit bandpassUnit;

AUGraph graph;

AUNode ioNode;

AUNode mixerNode;
AUNode mixer2Node;
AUNode mixer3Node;

AUNode distortionNode;
AUNode reverbNode;
AUNode compressionNode;
AUNode bandpassNode;

AudioComponentDescription io_desc;
AudioComponentDescription mixer_desc;
AudioComponentDescription distortion_desc;

AVAudioSession *audioSession;
AudioStreamBasicDescription	ioFormat;

BOOL effect1 = NO;
BOOL effect2 = NO;
BOOL effect3 = NO;
BOOL effect4 = NO;
BOOL effect5 = NO;

Float32 *getAudioBuffer()
{
    return audioBuffer;
}

int getAudioBufferLength()
{
    return audioBufferLen;
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
    
    result = AUGraphConnectNodeInput(graph, ioNode, inputChannel, mixerNode, 0);
    result = AUGraphConnectNodeInput(graph, mixerNode, 0, mixer2Node, 0);
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
    
    
    AVAudioSession *mySession = [AVAudioSession sharedInstance];
    
    // Specify that this object is the delegate of the audio session, so that
    //    this object's endInterruption method will be invoked when needed.
    // [mySession setDelegate: self];
    
    
    // Assign the Playback and Record category to the audio session.
    NSError *audioSessionError = nil;
    [mySession setCategory: AVAudioSessionCategoryPlayAndRecord
                     error: &audioSessionError];
    
    if (audioSessionError != nil) {
        NSLog (@"Error setting audio session category.");
    }
    
    if (![mySession inputIsAvailable]) {
        NSLog(@"input device is not available");
    }
    
    [mySession setPreferredHardwareSampleRate: 44100.0
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
    [mySession setActive: YES
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
    
    NSInteger numberOfChannels = [mySession currentHardwareInputNumberOfChannels];
    NSLog(@"number of channels: %d", numberOfChannels );
    
    
    AUNode ioNode;
    AUNode mixerNode;
    AUNode mixer2Node;
    AUNode mixer3Node;
    
    AUNode distortionNode;
    AUNode reverbNode;
    AUNode compressionNode;
    AUNode bandpassNode;
    
    result = NewAUGraph(&graph);
    
    AudioComponentDescription io_desc;
    io_desc.componentType                       = kAudioUnitType_Output;
    io_desc.componentSubType                    = kAudioUnitSubType_RemoteIO;
    io_desc.componentFlags                      = 0;
    io_desc.componentFlagsMask                  = 0;
    io_desc.componentManufacturer               = kAudioUnitManufacturer_Apple;
    
    AudioComponentDescription mixer_desc;
    mixer_desc.componentType                    = kAudioUnitType_Mixer;
    mixer_desc.componentSubType                 = kAudioUnitSubType_MultiChannelMixer;
    mixer_desc.componentFlags                   = 0;
    mixer_desc.componentFlagsMask               = 0;
    mixer_desc.componentManufacturer            = kAudioUnitManufacturer_Apple;
    
    AudioComponentDescription distortion_desc;
    distortion_desc.componentType               = kAudioUnitType_Effect;
    distortion_desc.componentSubType            = kAudioUnitSubType_Distortion;
    distortion_desc.componentFlags              = 0;
    distortion_desc.componentFlagsMask          = 0;
    distortion_desc.componentManufacturer       = kAudioUnitManufacturer_Apple;
    
    AudioComponentDescription reverb_desc;
    reverb_desc.componentType                   = kAudioUnitType_Effect;
    reverb_desc.componentSubType                = kAudioUnitSubType_Reverb2;
    reverb_desc.componentFlags                  = 0;
    reverb_desc.componentFlagsMask              = 0;
    reverb_desc.componentManufacturer           = kAudioUnitManufacturer_Apple;
    
    AudioComponentDescription compression_desc;
    compression_desc.componentType              = kAudioUnitType_Effect;
    compression_desc.componentSubType           = kAudioUnitSubType_DynamicsProcessor;
    compression_desc.componentFlags             = 0;
    compression_desc.componentFlagsMask         = 0;
    compression_desc.componentManufacturer      = kAudioUnitManufacturer_Apple;
    
    AudioComponentDescription bandpass_desc;
    bandpass_desc.componentType                  = kAudioUnitType_Effect;
    bandpass_desc.componentSubType               = kAudioUnitSubType_BandPassFilter;
    bandpass_desc.componentFlags                 = 0;
    bandpass_desc.componentFlagsMask             = 0;
    bandpass_desc.componentManufacturer          = kAudioUnitManufacturer_Apple;
    
    
    result = AUGraphAddNode(graph, &io_desc, &ioNode);
    result = AUGraphAddNode(graph, &mixer_desc, &mixerNode);
    result = AUGraphAddNode(graph, &mixer_desc, &mixer2Node);    
    
    result = AUGraphAddNode(graph, &distortion_desc, &distortionNode);
    result = AUGraphAddNode(graph, &reverb_desc, &reverbNode);
    result = AUGraphAddNode(graph, &compression_desc, &compressionNode);
    result = AUGraphAddNode(graph, &bandpass_desc, &bandpassNode);
    
    result = AUGraphAddNode(graph, &mixer_desc, &mixer3Node);      
    
    int outputChannel = 0;
    int inputChannel = 1;

    // standard
    result = AUGraphConnectNodeInput(graph, ioNode, inputChannel, mixerNode, 0);
    result = AUGraphConnectNodeInput(graph, mixerNode, 0, mixer2Node, 0);
    result = AUGraphConnectNodeInput(graph, mixer3Node, 0, ioNode, outputChannel);

    // shitty answering machine
//    result = AUGraphConnectNodeInput(graph, ioNode, inputChannel, mixerNode, 0);
//    result = AUGraphConnectNodeInput(graph, mixerNode, 0, distortionNode, 0);
//    result = AUGraphConnectNodeInput(graph, distortionNode, 0, bandpassNode, 0);
//    result = AUGraphConnectNodeInput(graph, bandpassNode, 0, compressionNode, 0);
//    result = AUGraphConnectNodeInput(graph, compressionNode, 0, mixer2Node, 0);
//    result = AUGraphConnectNodeInput(graph, mixer3Node, 0, ioNode, outputChannel);
    
/*    
    OSStatus AUGraphDisconnectNodeInput (
                                         AUGraph inGraph,
                                         AUNode inDestNode,
                                         UInt32 inDestInputNumber
                                         );
*/


    result = AUGraphOpen(graph);
    result = AUGraphNodeInfo(graph, ioNode, NULL, &ioUnit);
    result = AUGraphNodeInfo(graph, mixerNode, NULL, &mixerUnit);
    result = AUGraphNodeInfo(graph, mixer2Node, NULL, &mixer2Unit);

    result = AUGraphNodeInfo(graph, distortionNode, NULL, &distortionUnit);
    result = AUGraphNodeInfo(graph, compressionNode, NULL, &compressionUnit);
    result = AUGraphNodeInfo(graph, reverbNode, NULL, &reverbUnit);
    result = AUGraphNodeInfo(graph, bandpassNode, NULL, &bandpassUnit);

    UInt32 enableInput = 1;
    result = AudioUnitSetProperty(ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  1,
                                  &enableInput,
                                  sizeof(enableInput));
    
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc = &renderCallback;
    renderCallbackStruct.inputProcRefCon = &mixer2Unit;
    result = AUGraphSetNodeInputCallback(graph, mixer3Node, 0, &renderCallbackStruct);
    
    UInt32 asbdSize = sizeof(AudioStreamBasicDescription);
    memset (&ioFormat, 0, sizeof (ioFormat));
    
    result = AudioUnitGetProperty(compressionUnit,
                                  kAudioUnitProperty_StreamFormat, 
                                  kAudioUnitScope_Input, 
                                  0, 
                                  &ioFormat, 
                                  &asbdSize);
    
    
    
    
    //    size_t bytesPerSample = sizeof (AudioUnitSampleType);    
    //    ioFormat.mFormatID          = kAudioFormatLinearPCM;
    //    ioFormat.mFormatFlags       = kAudioFormatFlagIsFloat;
    //    ioFormat.mBytesPerPacket    = bytesPerSample;
    //    ioFormat.mFramesPerPacket   = 1;
    //    ioFormat.mBytesPerFrame     = bytesPerSample;
    //    ioFormat.mChannelsPerFrame  = 2;
    //    ioFormat.mBitsPerChannel    = 8 * bytesPerSample;
    //    ioFormat.mSampleRate        = 44100;
    
    
    result = AudioUnitSetProperty(mixerUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  &ioFormat,
                                  sizeof(ioFormat));
    
    result = AudioUnitSetProperty(mixer2Unit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &ioFormat,
                                  sizeof(ioFormat));
    
    
    //    result = AudioUnitSetProperty(mixerUnit,
    //                                  kAudioUnitProperty_ElementCount,
    //                                  kAudioUnitScope_Input,
    //                                  0,
    //                                  &busCount,
    //                                  sizeof (busCount));
    //    if (result != 0) {NSLog(@"FAIL: %ld", result);}
    
    result = AUGraphInitialize(graph);
    
    
    if (result != 0) {NSLog(@"FAIL: %ld", result);}
    
    if (result == 0) {
        NSLog(@"INIT SUCCEEDED");
    }
    else {
        NSLog(@"INIT FAILED: %ld", result);
    }
    
    CAShow(graph);
    
    AUGraphStart(graph);
    
    // AudioUnit Parameters have to be set after the Graph has been started
    
    
    
    /// <<- fx1 parameters (spacious)
    
    AudioUnitParameterID param1Type       = kReverb2Param_DecayTimeAtNyquist;
    AudioUnitParameterValue param1Amount  = 1.5;
    
    result = AudioUnitSetParameter(reverbUnit,
                                   param1Type,
                                   kAudioUnitScope_Global,
                                   0,                       // also 0, always
                                   param1Amount,            // value
                                   0);                      // it's...always 0
    
    if (result != 0) {NSLog(@"FAIL in effect SetParameter: %ld", result);}  
    
    
    
    AudioUnitParameterID param2Type       = kReverb2Param_DecayTimeAt0Hz;
    AudioUnitParameterValue param2Amount  = 2.5;
    
    result = AudioUnitSetParameter(reverbUnit,
                                   param2Type,
                                   kAudioUnitScope_Global,
                                   0,                       // also 0, always
                                   param2Amount,            // value
                                   0);                      // it's...always 0
    
    
    if (result != 0) {NSLog(@"FAIL in effect SetParameter: %ld", result);}      
    
    
    AudioUnitParameterID param3Type       = kReverb2Param_DryWetMix;
    AudioUnitParameterValue param3Amount  = 20;
    
    result = AudioUnitSetParameter(reverbUnit,
                                   param3Type,
                                   kAudioUnitScope_Global,
                                   0,                       // also 0, always
                                   param3Amount,            // value
                                   0);                      // it's...always 0
    
    
    if (result != 0) {NSLog(@"FAIL in effect SetParameter: %ld", result);}   
    
    
    
    AudioUnitParameterID param4Type       = kReverb2Param_RandomizeReflections;
    AudioUnitParameterValue param4Amount  = 100;
    
    result = AudioUnitSetParameter(reverbUnit,
                                   param4Type,
                                   kAudioUnitScope_Global,
                                   0,                       // also 0, always
                                   param4Amount,            // value
                                   0);                      // it's...always 0
    
    
    if (result != 0) {NSLog(@"FAIL in effect SetParameter: %ld", result);}   
    
    
    /// fx1 parameters
    
    
    
    
    
    /// fx2 parameters (bandpass)

    AudioUnitParameterID fx2Param1Type       = kBandpassParam_CenterFrequency;
    AudioUnitParameterValue fx2Param1Amount  = 2000;
    
    result = AudioUnitSetParameter(bandpassUnit,
                                   fx2Param1Type,
                                   kAudioUnitScope_Global,
                                   0,                           // also 0, always
                                   fx2Param1Amount,             // value
                                   0);                          // it's...always 0
    
    
    if (result != 0) {NSLog(@"FAIL in effect SetParameter: %ld", result);}   
    

    
    AudioUnitParameterID fx2Param2Type       = kBandpassParam_Bandwidth;
    AudioUnitParameterValue fx2Param2Amount  = 100;
    
    result = AudioUnitSetParameter(bandpassUnit,
                                   fx2Param2Type,
                                   kAudioUnitScope_Global,
                                   0,                           // also 0, always
                                   fx2Param2Amount,             // value
                                   0);                          // it's...always 0
    
    
    if (result != 0) {NSLog(@"FAIL in effect SetParameter: %ld", result);}   
    
    /// fx2 parameters
    
    
    /// fx3 parameters (brick wall compression)
    
    AudioUnitParameterID fx3Param1Type       = kDynamicsProcessorParam_ExpansionRatio;
    AudioUnitParameterValue fx3Param1Amount  = 50;
    
    result = AudioUnitSetParameter(compressionUnit,
                                   fx3Param1Type,
                                   kAudioUnitScope_Global,
                                   0,                           // also 0, always
                                   fx3Param1Amount,             // value
                                   0);                          // it's...always 0
    
    
    if (result != 0) {NSLog(@"FAIL in effect SetParameter: %ld", result);}   
    
    
    
    AudioUnitParameterID fx3Param2Type       = kDynamicsProcessorParam_Threshold;
    AudioUnitParameterValue fx3Param2Amount  = -40;
    
    result = AudioUnitSetParameter(compressionUnit,
                                   fx3Param2Type,
                                   kAudioUnitScope_Global,
                                   0,                           // also 0, always
                                   fx3Param2Amount,             // value
                                   0);                          // it's...always 0
    
    
    if (result != 0) {NSLog(@"FAIL in effect SetParameter: %ld", result);}   
    
    
    
    AudioUnitParameterID fx3Param3Type       = kDynamicsProcessorParam_MasterGain;
    AudioUnitParameterValue fx3Param3Amount  = 15;
    
    result = AudioUnitSetParameter(compressionUnit,
                                   fx3Param3Type,
                                   kAudioUnitScope_Global,
                                   0,                           // also 0, always
                                   fx3Param3Amount,             // value
                                   0);                          // it's...always 0
    
    
    if (result != 0) {NSLog(@"FAIL in effect SetParameter: %ld", result);}   
    
    
    AudioUnitParameterID fx3Param4Type       = kDynamicsProcessorParam_AttackTime;
    AudioUnitParameterValue fx3Param4Amount  = 0.0002;
    
    result = AudioUnitSetParameter(compressionUnit,
                                   fx3Param4Type,
                                   kAudioUnitScope_Global,
                                   0,                           // also 0, always
                                   fx3Param4Amount,             // value
                                   0);                          // it's...always 0
    
    
    if (result != 0) {NSLog(@"FAIL in effect SetParameter: %ld", result);}   
    
    
    
    AudioUnitParameterID fx3Param5Type       = kDynamicsProcessorParam_HeadRoom;
    AudioUnitParameterValue fx3Param5Amount  = 6;
    
    result = AudioUnitSetParameter(compressionUnit,
                                   fx3Param5Type,
                                   kAudioUnitScope_Global,
                                   0,                           // also 0, always
                                   fx3Param5Amount,             // value
                                   0);                          // it's...always 0
    
    
    if (result != 0) {NSLog(@"FAIL in effect SetParameter: %ld", result);}   
    
    
    
    
    /// fx3 parameters
    
    
    /// fx4 parameters (distortion)
    
    
    /// fx4 paramteters
    
    
    return result;
}

OSStatus enableEffect1(){
    OSStatus result = noErr;
    
    // cathedral
    result = AUGraphConnectNodeInput(graph, ioNode, inputChannel, mixerNode, 0);
    result = AUGraphConnectNodeInput(graph, mixerNode, 0, reverbNode, 0);
    result = AUGraphConnectNodeInput(graph, reverbNode, 0, mixer2Node, 0);
    result = AUGraphConnectNodeInput(graph, mixer3Node, 0, ioNode, outputChannel);

    effect1 = NO;
    return result;
}

OSStatus enableEffect2(){
    OSStatus result = noErr;
    
    
    effect2 = NO;
    return result;
}

OSStatus enableEffect3(){
    OSStatus result = noErr;
    
    
    effect3 = NO;
    return result;
}

OSStatus enableEffect4(){
    OSStatus result = noErr;
    
    
    effect4 = NO;
    return result;
}

OSStatus enableEffect5(){
    OSStatus result = noErr;
    
    
    effect5 = NO;
    return result;
}




OSStatus disableEffect1(){
    OSStatus result = noErr;
    
    result = AUGraphDisconnectNodeInput(graph, reverbNode, 0); // first effect unit
    result = AUGraphDisconnectNodeInput(graph, mixer2Node, 0); // first output unit
    
    result = AUGraphConnectNodeInput(graph, mixerNode, 0, mixer2Node, 0);
    
    BOOL isUpdated = NO;
    result = AUGraphUpdate(graph, &isUpdated);
    effect1 = NO;
    return result;
}

OSStatus disableEffect2(){
    OSStatus result = noErr;
    
    
    effect2 = NO;
    return result;
}

OSStatus disableEffect3(){
    OSStatus result = noErr;
    
    
    effect3 = NO;
    return result;
}

OSStatus disableEffect4(){
    OSStatus result = noErr;
    
    
    effect4 = NO;
    return result;
}

OSStatus disableEffect5(){
    OSStatus result = noErr;
    
    
    effect5 = NO;
    return result;
}


void toggleEffect1(){ NSLog(@"toggleEffect1() called!"); effect1==YES ? disableEffect1() : enableEffect1(); }
void toggleEffect2(){ effect2==YES ? disableEffect2() : enableEffect2(); }
void toggleEffect3(){ effect3==YES ? disableEffect3() : enableEffect3(); }
void toggleEffect4(){ effect4==YES ? disableEffect4() : enableEffect4(); }
void toggleEffect5(){ effect5==YES ? disableEffect5() : enableEffect5(); }
