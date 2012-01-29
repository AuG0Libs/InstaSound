
#import "AppDelegate.h"
#import "AudioToolbox/AudioToolbox.h"
#import "AVFoundation/AVFoundation.h"
#import "ViewController.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize eaglView = _eaglView;
@synthesize viewController = _viewController;
@synthesize navigationBar = _navigationBar;
@synthesize buttonBar = _buttonBar;

@synthesize unitIsRunning;
@synthesize unitHasBeenCreated;

Float32 audioBuffer[32 * 1024 * 1024];

int audioBufferLen = 0;
int points = 1024;

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

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Make it red to see size issues
    [self.window setBackgroundColor:[UIColor redColor]];
    
    [self initializeEAGLView];
    [self initializeNavigationView];
    [self initializeButtons];
    
    [self.window addSubview:self.eaglView];
    [self.window addSubview:self.navigationBar];
    [self.window addSubview:self.buttonBar];

    // self.viewController.view = view;
    // self.window.rootViewController = self.viewController;

    [self.window makeKeyAndVisible];

    return YES;
}

- (void) initializeEAGLView
{
    oscilLine = (GLfloat*)malloc(points * 2 * sizeof(GLfloat));
    
    
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
    mixer_desc.componentFlags           = 0;
    mixer_desc.componentFlagsMask       = 0;
    mixer_desc.componentManufacturer    = kAudioUnitManufacturer_Apple;
    
    AudioComponentDescription distortion_desc;
    distortion_desc.componentType            = kAudioUnitType_Effect;
    distortion_desc.componentSubType         = kAudioUnitSubType_Distortion;
    distortion_desc.componentFlags           = 0;
    distortion_desc.componentFlagsMask       = 0;
    distortion_desc.componentManufacturer    = kAudioUnitManufacturer_Apple;
    
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
    // result = AUGraphConnectNodeInput(graph, mixer2Node, 0, mixer3Node, 0);
    result = AUGraphConnectNodeInput(graph, mixer3Node, 0, ioNode, outputChannel);
    
    result = AUGraphOpen(graph);
    result = AUGraphNodeInfo(graph, ioNode, NULL, &ioUnit);
    result = AUGraphNodeInfo(graph, mixerNode, NULL, &mixerUnit);
    result = AUGraphNodeInfo(graph, mixer2Node, NULL, &mixer2Unit);
    result = AUGraphNodeInfo(graph, distortionNode, NULL, &distortionUnit);

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
    
    result = AudioUnitGetProperty(distortionUnit,
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

    if (result != 0) {NSLog(@"FAIL: %ld", result);}
    
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
    
    unitHasBeenCreated = true;
    unitIsRunning = 1;
       
    // top: 20 (statusbar) + 44 (navigationBar)
    // height: 480 (whole screen) - 49 (bottombar) - 64 (topbar)
    self.eaglView = [[EAGLView alloc] initWithFrame: CGRectMake(0, 64, 320, 367)];
    
    self.eaglView.delegate = self;
    
    [self.eaglView setAnimationInterval:1./20.];
    [self.eaglView startAnimation];
}

- (void)initializeNavigationView
{
    self.navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 20, 1, 1)];
    [self.navigationBar setBarStyle:UIBarStyleBlackOpaque];
    
    UINavigationItem *title = [[UINavigationItem alloc] initWithTitle:@"InstaGramophone"];
    [self.navigationBar pushNavigationItem:title animated:true];

    [self.navigationBar sizeToFit];
}

- (void)initializeButtons
{
    self.buttonBar = [[UITabBar alloc] initWithFrame:CGRectMake(0, 431, 320, 49)];

    NSString* pathToImageFile = [[NSBundle mainBundle] pathForResource:@"icon_Vinyl" ofType:@"png"];
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:pathToImageFile];
    UITabBarItem *church = [[UITabBarItem alloc] initWithTitle:@"Church" image:image tag:1];
    
    [self.buttonBar setItems:[NSArray arrayWithObjects: church, nil]];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    eaglView.applicationResignedActive = NO;
    [eaglView startAnimation];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    eaglView.applicationResignedActive = YES;
    [eaglView stopAnimation];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)dealloc {
	free(oscilLine);
}

- (void)drawOscilloscope {

	glClear(GL_COLOR_BUFFER_BIT);

	glBlendFunc(GL_SRC_ALPHA, GL_ONE);

	glPushMatrix();

	// glTranslatef(0., 480., 0.);
	// glRotatef(-90., 0., 0., 1.);

	glEnable(GL_TEXTURE_2D);
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);

	glPushMatrix();

	glTranslatef(0, 0, 0.);
	glScalef(320., 300., 1.);

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
            oscilLine[i * 2 + 1] = audioBuffer[offset + i * 256];
        }
    }

    glColor4f(0.5, 0.5, 0.5, 1.);
    glVertexPointer(2, GL_FLOAT, 0, oscilLine);
    glDrawArrays(GL_LINE_STRIP, 0, points);

	glPopMatrix();
	glPopMatrix();
}

- (void)drawView:(id)sender forTime:(NSTimeInterval)time {
    [self drawOscilloscope];
}


@end
