#import "AudioPreset.h"

@implementation AudioPreset

@synthesize enabled;

- (AudioPreset *) create:(AUGraph) _graph
{
    graph = _graph;

    [self initDescriptions];

    enabled = NO;

    nodeCount = 0;

    AUGraphAddNode(graph, &reverb_desc, &reverbNode);
    AUGraphAddNode(graph, &compression_desc, &compressionNode);
    AUGraphAddNode(graph, &bandpass_desc, &bandpassNode);
    AUGraphAddNode(graph, &highshelf_desc, &highshelfNode);
    AUGraphAddNode(graph, &distortion_desc, &distortionNode);
    AUGraphAddNode(graph, &fileplayer_desc, &fileplayerNode);
    
    AUGraphNodeInfo(graph, distortionNode, NULL, &distortionUnit);
    AUGraphNodeInfo(graph, compressionNode, NULL, &compressionUnit);
    AUGraphNodeInfo(graph, reverbNode, NULL, &reverbUnit);
    AUGraphNodeInfo(graph, bandpassNode, NULL, &bandpassUnit);
    AUGraphNodeInfo(graph, highshelfNode, NULL, &highshelfUnit);
    AUGraphNodeInfo(graph, fileplayerNode, NULL, &fileplayerUnit);

    return self;
}

- (void) enableFile: (NSString *)file ofType:(NSString *)type withFormat:(AudioStreamBasicDescription)ioFormat
{

    OSStatus result;
    NSLog(@"enableFile: %@", file);    
    NSLog(@"enableFile: %@", type);
    
    nodes[nodeCount++] = fileplayerNode;
    
    AudioFileID filePlayerFile;
    
    NSString *filePath;
    
    filePath = [[NSBundle mainBundle] pathForResource: file ofType: type];
    NSLog(@"enableFile, filePath: %@", filePath);
    



	
    
    
    
	CFURLRef audioURL = (__bridge CFURLRef) [NSURL fileURLWithPath:filePath];
    NSLog(@"enableFile, filePath: %@", audioURL);	
	result = AudioFileOpenURL(audioURL, kAudioFileReadPermission, 0, &filePlayerFile);
    NSLog(@"AudioFileOpenURL: %ld", result);
	// tell the file player unit to load the file we want to play
    result = AudioUnitSetProperty(fileplayerUnit, kAudioUnitProperty_ScheduledFileIDs, 
                         kAudioUnitScope_Global, 0, &filePlayerFile, sizeof(filePlayerFile));
    NSLog(@"AudioUnitSetProperty: %ld", result);    
	UInt64 nPackets;
	UInt32 propsize = sizeof(nPackets);
	result = AudioFileGetProperty(filePlayerFile, kAudioFilePropertyAudioDataPacketCount,
                         &propsize, &nPackets);
    NSLog(@"AudioFileGetProperty: %ld", result);
	// get file's asbd
	AudioStreamBasicDescription fileASBD;
	UInt32 fileASBDPropSize = sizeof(fileASBD);
	result = AudioFileGetProperty(filePlayerFile, 
                         kAudioFilePropertyDataFormat,
                         &fileASBDPropSize,
                         &fileASBD);
    
	// tell the file player AU to play the entire file
    ScheduledAudioFileRegion rgn;
    
	memset (&rgn.mTimeStamp, 0, sizeof(rgn.mTimeStamp));
	
    rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
	rgn.mTimeStamp.mSampleTime = 0;
	rgn.mCompletionProc = NULL;
	rgn.mCompletionProcUserData = NULL;
	rgn.mAudioFile = filePlayerFile;
	rgn.mLoopCount = INT_MAX;
	rgn.mStartFrame = 0;
	rgn.mFramesToPlay = nPackets * fileASBD.mFramesPerPacket;
	
	result = AudioUnitSetProperty(fileplayerUnit, 
                                  kAudioUnitProperty_ScheduledFileRegion, 
                                  kAudioUnitScope_Global, 
                                  0,
                                  &rgn,
                                  sizeof(rgn));

	// prime the file player AU with default values
	UInt32 defaultVal = 0;
	result = AudioUnitSetProperty(fileplayerUnit, 
                                  kAudioUnitProperty_ScheduledFilePrime, 
                                  kAudioUnitScope_Global, 
                                  0, 
                                  &defaultVal, 
                                  sizeof(defaultVal));
    
    result = AudioUnitSetProperty(fileplayerUnit, 
                         kAudioUnitProperty_StreamFormat, 
                         kAudioUnitScope_Output, 
                         0, 
                         &ioFormat,
                         sizeof(ioFormat));
	
	// tell the file player AU when to start playing (-1 sample time means next render cycle)
	AudioTimeStamp startTime;
	memset (&startTime, 0, sizeof(startTime));
    
	startTime.mFlags = kAudioTimeStampSampleTimeValid;
	startTime.mSampleTime = -1;
	
    result = AudioUnitSetProperty(fileplayerUnit, kAudioUnitProperty_ScheduleStartTimeStamp, 
                                  kAudioUnitScope_Global, 0, &startTime, sizeof(startTime));
    
    NSLog(@"AudioUnitSetProperty: %d", result);
}

- (void) enableDistortion
{
    nodes[nodeCount++] = distortionNode;
}

- (void) enableReverb
{
    nodes[nodeCount++] = reverbNode; 
}

- (void) enableBandpass
{
    nodes[nodeCount++] = bandpassNode;
}

- (void) enableHighshelf
{
    nodes[nodeCount++] = highshelfNode;
}

- (void) enableCompression
{
    nodes[nodeCount++] = compressionNode;    
}


- (AudioPreset *) connect:(AUNode)input with:(AUNode)output on:(int)channel
{
    AUGraphConnectNodeInput(graph, input, 0, nodes[0], 0);

    for (int i = 0; i < nodeCount - 1; i++) {
        AUGraphConnectNodeInput(graph, nodes[i], 0, nodes[i + 1], 0);
    }

    AUGraphConnectNodeInput(graph, nodes[nodeCount-1], 0, output, channel);

    return self;
}

- (AudioPreset *) disconnect:(AUNode)output;
{
    return self;
}

- (void) initDescriptions
{
    distortion_desc.componentType               = kAudioUnitType_Effect;
    distortion_desc.componentSubType            = kAudioUnitSubType_Distortion;
    distortion_desc.componentFlags              = 0;
    distortion_desc.componentFlagsMask          = 0;
    distortion_desc.componentManufacturer       = kAudioUnitManufacturer_Apple;

    reverb_desc.componentType                   = kAudioUnitType_Effect;
    reverb_desc.componentSubType                = kAudioUnitSubType_Reverb2;
    reverb_desc.componentFlags                  = 0;
    reverb_desc.componentFlagsMask              = 0;
    reverb_desc.componentManufacturer           = kAudioUnitManufacturer_Apple;

    compression_desc.componentType              = kAudioUnitType_Effect;
    compression_desc.componentSubType           = kAudioUnitSubType_DynamicsProcessor;
    compression_desc.componentFlags             = 0;
    compression_desc.componentFlagsMask         = 0;
    compression_desc.componentManufacturer      = kAudioUnitManufacturer_Apple;

    bandpass_desc.componentType                 = kAudioUnitType_Effect;
    bandpass_desc.componentSubType              = kAudioUnitSubType_BandPassFilter;
    bandpass_desc.componentFlags                = 0;
    bandpass_desc.componentFlagsMask            = 0;
    bandpass_desc.componentManufacturer         = kAudioUnitManufacturer_Apple;

    highshelf_desc.componentType                = kAudioUnitType_Effect;
    highshelf_desc.componentSubType             = kAudioUnitSubType_HighShelfFilter;
    highshelf_desc.componentFlags               = 0;
    highshelf_desc.componentFlagsMask           = 0;
    highshelf_desc.componentManufacturer        = kAudioUnitManufacturer_Apple;

    fileplayer_desc.componentType               = kAudioUnitType_Generator;
    fileplayer_desc.componentSubType            = kAudioUnitSubType_AudioFilePlayer;
    fileplayer_desc.componentFlags              = 0;
    fileplayer_desc.componentFlagsMask          = 0;
    fileplayer_desc.componentManufacturer       = kAudioUnitManufacturer_Apple;
}

- (id) distortion: (AudioUnitParameterID)type to:(AudioUnitParameterValue) value
{
    AudioUnitSetParameter(distortionUnit, type, kAudioUnitScope_Global, 0, value, 0);
    return self;
}

- (id) reverb: (AudioUnitParameterID)type to:(AudioUnitParameterValue) value
{
    AudioUnitSetParameter(reverbUnit, type, kAudioUnitScope_Global, 0, value, 0);
    return self;
}

- (id) compression: (AudioUnitParameterID)type to:(AudioUnitParameterValue) value
{
    AudioUnitSetParameter(compressionUnit, type, kAudioUnitScope_Global, 0, value, 0);
    return self;
}

- (id) bandpass: (AudioUnitParameterID)type to:(AudioUnitParameterValue) value
{
    AudioUnitSetParameter(bandpassUnit, type, kAudioUnitScope_Global, 0, value, 0);
    return self;
}

- (id) highshelf: (AudioUnitParameterID)type to:(AudioUnitParameterValue) value
{
    AudioUnitSetParameter(highshelfUnit, type, kAudioUnitScope_Global, 0, value, 0);
    return self;
}
@end
