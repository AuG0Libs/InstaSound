
#import "aurioTouchAppDelegate.h"
#import "AudioToolbox/AudioToolbox.h"
#import "CAXException.h"

@implementation aurioTouchAppDelegate

@synthesize window;
@synthesize view;

@synthesize rioUnit;
@synthesize unitIsRunning;
@synthesize unitHasBeenCreated;
@synthesize inputProc;

#pragma mark-

#pragma mark -Audio Session Interruption Listener

void rioInterruptionListener(void *inClientData, UInt32 inInterruption)
{
	printf("Session interrupted! --- %s ---", inInterruption == kAudioSessionBeginInterruption ? "Begin Interruption" : "End Interruption");
	
	aurioTouchAppDelegate *THIS = (aurioTouchAppDelegate*)inClientData;
	
	if (inInterruption == kAudioSessionEndInterruption) {
		// make sure we are again the active session
		XThrowIfError(AudioSessionSetActive(true), "couldn't set audio session active");
		XThrowIfError(AudioOutputUnitStart(THIS->rioUnit), "couldn't start unit");
	}
	
	if (inInterruption == kAudioSessionBeginInterruption) {
		XThrowIfError(AudioOutputUnitStop(THIS->rioUnit), "couldn't stop unit");
    }
}

SInt16 audioBuffer[32 * 1024 * 1024];

int audioBufferLen = 0;
int points = 1024;

#pragma mark -Audio Session Property Listener

void propListener(	void *                  inClientData,
					AudioSessionPropertyID	inID,
					UInt32                  inDataSize,
					const void *            inData)
{
	aurioTouchAppDelegate *THIS = (aurioTouchAppDelegate*)inClientData;
	if (inID == kAudioSessionProperty_AudioRouteChange)
	{
		try {
			 UInt32 isAudioInputAvailable; 
			 UInt32 size = sizeof(isAudioInputAvailable);
			 XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, &size, &isAudioInputAvailable), "couldn't get AudioSession AudioInputAvailable property value");
			 
			 if(THIS->unitIsRunning && !isAudioInputAvailable)
			 {
				 XThrowIfError(AudioOutputUnitStop(THIS->rioUnit), "couldn't stop unit");
				 THIS->unitIsRunning = false;
			 }
			 
			 else if(!THIS->unitIsRunning && isAudioInputAvailable)
			 {
				 XThrowIfError(AudioSessionSetActive(true), "couldn't set audio session active\n");
			 
				 if (!THIS->unitHasBeenCreated)	// the rio unit is being created for the first time
				 {
					 XThrowIfError(SetupRemoteIO(THIS->rioUnit, THIS->inputProc, THIS->thruFormat), "couldn't setup remote i/o unit");
					 THIS->unitHasBeenCreated = true;
					 
					 THIS->dcFilter = new DCRejectionFilter[THIS->thruFormat.NumberChannels()];
					 
					 UInt32 maxFPS;
					 size = sizeof(maxFPS);
					 XThrowIfError(AudioUnitGetProperty(THIS->rioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, &size), "couldn't get the remote I/O unit's max frames per slice");
					 
				 }
				 
				 XThrowIfError(AudioOutputUnitStart(THIS->rioUnit), "couldn't start unit");
				 THIS->unitIsRunning = true;
			 }
						
		} catch (CAXException e) {
			char buf[256];
			fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		}
		
	}
}

#pragma mark -RIO Render Callback

static OSStatus	PerformThru(
							void						*inRefCon, 
							AudioUnitRenderActionFlags 	*ioActionFlags, 
							const AudioTimeStamp 		*inTimeStamp, 
							UInt32 						inBusNumber, 
							UInt32 						inNumberFrames, 
							AudioBufferList 			*ioData)
{
	aurioTouchAppDelegate *THIS = (aurioTouchAppDelegate *)inRefCon;
	OSStatus err = AudioUnitRender(THIS->rioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
	if (err) { printf("PerformThru: error %d\n", (int)err); return err; }
	
	// Remove DC component
	for(UInt32 i = 0; i < ioData->mNumberBuffers; ++i)
		THIS->dcFilter[i].InplaceFilter((SInt32*)(ioData->mBuffers[i].mData), inNumberFrames, 1);
	  
    SInt8 *data = (SInt8 *)(ioData->mBuffers[0].mData);
    
    for (int i = 0; i < inNumberFrames; i++)
    {
        audioBuffer[audioBufferLen + i] = data[2];
        data += 4;
    }

    audioBufferLen += inNumberFrames;
    
	return err;
}

#pragma mark-

- (void)applicationDidFinishLaunching:(UIApplication *)application
{	
    oscilLine = (GLfloat*)malloc(points * 2 * sizeof(GLfloat));
    
	// Turn off the idle timer, since this app doesn't rely on constant touch input
	application.idleTimerDisabled = YES;
		
	// Initialize our remote i/o unit
	
	inputProc.inputProc = PerformThru;
	inputProc.inputProcRefCon = self;

	try {	
		
		// Initialize and configure the audio session
		XThrowIfError(AudioSessionInitialize(NULL, NULL, rioInterruptionListener, self), "couldn't initialize audio session");
			
		UInt32 audioCategory = kAudioSessionCategory_PlayAndRecord;
		XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory), "couldn't set audio category");
		XThrowIfError(AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propListener, self), "couldn't set property listener");

		Float32 preferredBufferSize = .005;
		XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(preferredBufferSize), &preferredBufferSize), "couldn't set i/o buffer duration");
		
		UInt32 size = sizeof(hwSampleRate);
		XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &hwSampleRate), "couldn't get hw sample rate");
		
		XThrowIfError(AudioSessionSetActive(true), "couldn't set audio session active\n");

		XThrowIfError(SetupRemoteIO(rioUnit, inputProc, thruFormat), "couldn't setup remote i/o unit");
		unitHasBeenCreated = true;
		
		dcFilter = new DCRejectionFilter[thruFormat.NumberChannels()];

		UInt32 maxFPS;
		size = sizeof(maxFPS);
		XThrowIfError(AudioUnitGetProperty(rioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, &size), "couldn't get the remote I/O unit's max frames per slice");
		
		XThrowIfError(AudioOutputUnitStart(rioUnit), "couldn't start remote i/o unit");

		size = sizeof(thruFormat);
		XThrowIfError(AudioUnitGetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &thruFormat, &size), "couldn't get the remote I/O unit's output client format");
		
		unitIsRunning = 1;
	}
	catch (CAXException &e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		unitIsRunning = 0;
		if (dcFilter) delete[] dcFilter;
	}
	catch (...) {
		fprintf(stderr, "An unknown error occurred\n");
		unitIsRunning = 0;
		if (dcFilter) delete[] dcFilter;
	}
	
	// Set ourself as the delegate for the EAGLView so that we get drawing and touch events
	view.delegate = self;
	
	// Enable multi touch so we can handle pinch and zoom in the oscilloscope
	view.multipleTouchEnabled = YES;

	// Set up the view to refresh at 20 hz
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


- (void)dealloc
{	
	delete[] dcFilter;
	
	[view release];
	[window release];
	
	free(oscilLine);

	[super dealloc];
}


- (void)drawOscilloscope
{
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
            oscilLine[i * 2 + 1] = ((Float32) audioBuffer[offset + i * 256]) / 128.0;
        }
    }
		
    glColor4f(0., 1., 0., 1.);
    glVertexPointer(2, GL_FLOAT, 0, oscilLine);
    glDrawArrays(GL_LINE_STRIP, 0, points);
	
	glPopMatrix();
	glPopMatrix();
}

- (void)drawView:(id)sender forTime:(NSTimeInterval)time
{
    [self drawOscilloscope];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{

}

@end
