
#import "aurioTouchAppDelegate.h"
#import "AudioToolbox/AudioToolbox.h"
#import "AVFoundation/AVFoundation.h"
#import "CAXException.h"

@implementation aurioTouchAppDelegate

@synthesize window;
@synthesize view;

@synthesize unitIsRunning;
@synthesize unitHasBeenCreated;

SInt16 audioBuffer[32 * 1024 * 1024];

int audioBufferLen = 0;
int points = 1024;

static OSStatus	renderCallback(void                         *inRefCon,
                               AudioUnitRenderActionFlags 	*ioActionFlags,
                               const AudioTimeStamp 		*inTimeStamp,
                               UInt32 						inBusNumber,
                               UInt32 						inNumberFrames,
                               AudioBufferList              *ioData) {

    SInt8 *data = (SInt8 *)(ioData->mBuffers[0].mData);

    for (int i = 0; i < inNumberFrames; i++)
    {
        audioBuffer[audioBufferLen + i] = data[i * 4 + 2] << 8 | (UInt8) data[i * 4 + 3];
    }

    audioBufferLen += inNumberFrames;

	return 0;
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {

    oscilLine = (GLfloat*)malloc(points * 2 * sizeof(GLfloat));

	try {	
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

        OSStatus result = noErr;

        result = NewAUGraph(&graph);

        AudioComponentDescription io_desc;
        io_desc.componentType               = kAudioUnitType_Output;
        io_desc.componentSubType            = kAudioUnitSubType_RemoteIO;
        io_desc.componentFlags              = 0;
        io_desc.componentFlagsMask          = 0;
        io_desc.componentManufacturer       = kAudioUnitManufacturer_Apple;

        AudioComponentDescription mixer_desc;
        mixer_desc.componentType            = kAudioUnitType_Mixer;
        mixer_desc.componentSubType         = kAudioUnitSubType_MultiChannelMixer;
        mixer_desc.componentManufacturer    = kAudioUnitManufacturer_Apple;
        mixer_desc.componentFlags           = 0;
        mixer_desc.componentFlagsMask       = 0;

        result = AUGraphAddNode(graph, &io_desc, &ioNode);
        result = AUGraphAddNode(graph, &mixer_desc, &mixerNode);

        AUGraphConnectNodeInput(graph, mixerNode, 0, ioNode, 0);
        AUGraphConnectNodeInput(graph, ioNode, 1, mixerNode, 1);
        
        result = AUGraphOpen(graph);
        result = AUGraphNodeInfo(graph, ioNode, NULL, &ioUnit);
        result = AUGraphNodeInfo(graph, mixerNode, NULL, &mixerUnit);

        UInt32 enableInput = 1;
		result = AudioUnitSetProperty(ioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Input,
                                      1,
                                      &enableInput,
                                      sizeof(enableInput));

        AURenderCallbackStruct renderCallbackStruct;
        renderCallbackStruct.inputProc = &renderCallback;
        renderCallbackStruct.inputProcRefCon = self;

        result = AUGraphSetNodeInputCallback(graph, mixerNode, 0, &renderCallbackStruct);

        size_t bytesPerSample = sizeof (AudioUnitSampleType);

        ioFormat.mFormatID          = kAudioFormatLinearPCM;
        ioFormat.mFormatFlags       = kAudioFormatFlagsAudioUnitCanonical;
        ioFormat.mBytesPerPacket    = bytesPerSample;
        ioFormat.mFramesPerPacket   = 1;
        ioFormat.mBytesPerFrame     = bytesPerSample;
        ioFormat.mChannelsPerFrame  = 1;
        ioFormat.mBitsPerChannel    = 8 * bytesPerSample;
        ioFormat.mSampleRate        = 44100;

        int busCount = 6;

        result = AudioUnitSetProperty(ioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      0,
                                      &ioFormat,
                                      sizeof(ioFormat));

        result = AudioUnitSetProperty (mixerUnit,
                                       kAudioUnitProperty_ElementCount,
                                       kAudioUnitScope_Input,
                                       0,
                                       &busCount,
                                       sizeof (busCount));

        result = AUGraphInitialize(graph);
        CAShow(graph);

        AUGraphStart(graph);

        unitHasBeenCreated = true;
		unitIsRunning = 1;
	}
	catch (CAXException &e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		unitIsRunning = 0;
	}
	catch (...) {
		fprintf(stderr, "An unknown error occurred\n");
		unitIsRunning = 0;
	}

	view.delegate = self;
	view.multipleTouchEnabled = YES;
	[view setAnimationInterval:1./20.];
	[view startAnimation];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    view.applicationResignedActive = NO;
	[view startAnimation];
	AudioSessionSetActive(true);
}

- (void)applicationWillResignActive:(UIApplication *)application {
    view.applicationResignedActive = YES;
    [view stopAnimation];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)dealloc {
	[view release];
	[window release];

	free(oscilLine);

	[super dealloc];
}

- (void)drawOscilloscope {

	glClear(GL_COLOR_BUFFER_BIT);

	glBlendFunc(GL_SRC_ALPHA, GL_ONE);

	glColor4f(1., 1., 1., 1.);

	glPushMatrix();

	glTranslatef(0., 480., 0.);
	glRotatef(-90., 0., 0., 1.);

	glEnable(GL_TEXTURE_2D);
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);

	glPushMatrix();

	glTranslatef(17., 182., 0.);
	glScalef(448., 116., 1.);

	glDisable(GL_TEXTURE_2D);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glDisableClientState(GL_COLOR_ARRAY);
	glDisable(GL_LINE_SMOOTH);
	glLineWidth(2.);

    if (audioBufferLen > 0) {
        int offset = MAX(0, audioBufferLen - points * 256);

        for (int i = 0; i < points; i++)
        {
            oscilLine[i * 2 + 0] = ((Float32) i) / points;
            oscilLine[i * 2 + 1] = ((Float32) audioBuffer[offset + i * 256]) / 32768.0;
        }
    }

    glColor4f(0., 1., 0., 1.);
    glVertexPointer(2, GL_FLOAT, 0, oscilLine);
    glDrawArrays(GL_LINE_STRIP, 0, points);

	glPopMatrix();
	glPopMatrix();
}

- (void)drawView:(id)sender forTime:(NSTimeInterval)time {
    [self drawOscilloscope];
}


@end
