
#import "aurioTouchAppDelegate.h"
#import "AudioToolbox/AudioToolbox.h"
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
		AudioSessionInitialize(NULL, NULL, NULL, self);

		Float32 preferredBufferSize = .005;
		AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(preferredBufferSize), &preferredBufferSize);

		AudioSessionSetActive(true);

        AUNode ioNode;
        AUNode mixerNode;

        OSStatus result = noErr;

        result = NewAUGraph(&graph);

        AudioComponentDescription io_desc;
        io_desc.componentType = kAudioUnitType_Output;
        io_desc.componentSubType = kAudioUnitSubType_RemoteIO;
        io_desc.componentFlags = 0;
        io_desc.componentFlagsMask = 0;
        io_desc.componentManufacturer = kAudioUnitManufacturer_Apple;

        // Multichannel mixer unit
        AudioComponentDescription mixer_desc;
        mixer_desc.componentType          = kAudioUnitType_Mixer;
        mixer_desc.componentSubType       = kAudioUnitSubType_MultiChannelMixer;
        mixer_desc.componentManufacturer  = kAudioUnitManufacturer_Apple;
        mixer_desc.componentFlags         = 0;
        mixer_desc.componentFlagsMask     = 0;

        result = AUGraphAddNode(graph, &io_desc, &ioNode);
        result = AUGraphAddNode(graph, &mixer_desc, &mixerNode);

        AUGraphConnectNodeInput(graph, mixerNode, 0, ioNode, 0);

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
        ioFormat.mChannelsPerFrame  = 1;                  // 1 indicates mono
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
	//start animation now that we're in the foreground
    view.applicationResignedActive = NO;
	[view startAnimation];
	AudioSessionSetActive(true);
}

- (void)applicationWillResignActive:(UIApplication *)application {
	//stop animation before going into background
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
	// Clear the view
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

	// Translate to the left side and vertical center of the screen, and scale so that the screen coordinates
	// go from 0 to 1 along the X, and -1 to 1 along the Y
	glTranslatef(17., 182., 0.);
	glScalef(448., 116., 1.);

	// Set up some GL state for our oscilloscope lines
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

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {

}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {

}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {

}

@end
