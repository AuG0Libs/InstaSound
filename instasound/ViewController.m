//
//  ViewController.m
//  singleview
//
//  Created by matti on 29/01/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#import "SCUI.h"
#import "AudioEngine.h"

@implementation ViewController

@synthesize navigationBar = _navigationBar;
@synthesize toolBar = _buttonBar;
@synthesize eaglView = _eaglView;
@synthesize recordButton = _recordButton;

int points = 1024;
int recordingStart = -1;
int recordingLength = -1;

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    audioEngine = [[AudioEngine alloc] init];
    
    [self initializeNavigationView];
    [self initializeButtons];
    [self initializeEAGL];
    [self initializeRecordButton];
}

- (void)initializeNavigationView
{
    self.navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    [self.navigationBar setBarStyle:UIBarStyleBlackOpaque];
    
    //    UIImage *image = [UIImage imageNamed:@"instasound_small.png"];
    //    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    //    [self.navigationBar addSubview:imageView];
    UINavigationItem *title = [[UINavigationItem alloc] initWithTitle:@"InstaSound"];
    [self.navigationBar pushNavigationItem:title animated:true];
    [self.navigationBar sizeToFit];
    
    [self.view addSubview:self.navigationBar];
}

- (void)initializeButtons
{
    self.toolBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 411, 320, 49)];
    [self.toolBar setBarStyle:UIBarStyleBlackOpaque];
    
    NSString* pathToImageFile = [[NSBundle mainBundle] pathForResource:@"icon_Church" ofType:@"png"];
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:pathToImageFile];
    UIBarButtonItem *effect1 = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(effect1)];
    
    pathToImageFile = [[NSBundle mainBundle] pathForResource:@"icon_Phone" ofType:@"png"];
    image = [[UIImage alloc] initWithContentsOfFile:pathToImageFile];
    UIBarButtonItem *effect2 = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(effect2)];
    
    pathToImageFile = [[NSBundle mainBundle] pathForResource:@"icon_Enhancer" ofType:@"png"];
    image = [[UIImage alloc] initWithContentsOfFile:pathToImageFile];
    UIBarButtonItem *effect3 = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(effect3)];
    
    pathToImageFile = [[NSBundle mainBundle] pathForResource:@"icon_Radio" ofType:@"png"];
    image = [[UIImage alloc] initWithContentsOfFile:pathToImageFile];
    UIBarButtonItem *effect4 = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(effect2)];
    
    pathToImageFile = [[NSBundle mainBundle] pathForResource:@"icon_Vinyl" ofType:@"png"];
    image = [[UIImage alloc] initWithContentsOfFile:pathToImageFile];
    UIBarButtonItem *effect5 = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(effect5)];
    
    [self.toolBar setItems:[NSArray arrayWithObjects: effect1, effect2, effect3, effect4, effect5, nil]];
    
    [self.view addSubview:self.toolBar];
}

- (void)initializeEAGL
{
    oscilLine = (GLfloat*)malloc(points * 2 * sizeof(GLfloat));
    
    // top: 44 (navigationBar)
    // height: 480 (whole screen) - 49 (bottombar) - 44 (topbar)
    self.eaglView = [[EAGLView alloc] initWithFrame: CGRectMake(0, 44, 320, 367)];
    self.eaglView.delegate = self;
    
    [self.eaglView setAnimationInterval:1./20.];
    [self.eaglView startAnimation];
    
    [self.view addSubview:self.eaglView];
}

- (void)initializeRecordButton
{
    self.recordButton = [[UIButton alloc] initWithFrame:CGRectMake(99, 171, 123, 123)];
    
    NSString* pathToImageFile = [[NSBundle mainBundle] pathForResource:@"Record" ofType:@"png"];
    [self.recordButton setImage:[[UIImage alloc] initWithContentsOfFile:pathToImageFile] forState:UIControlStateNormal];
    [self.recordButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentCenter];
    [self.recordButton setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
    [self.recordButton addTarget:self action:@selector(record) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.recordButton];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.eaglView.applicationResignedActive = NO;
    [self.eaglView startAnimation];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
    self.eaglView.applicationResignedActive = YES;
    [self.eaglView stopAnimation];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (void)effect1{ [audioEngine toggleEffect:1]; }
- (void)effect2{ [audioEngine toggleEffect:2]; }
- (void)effect3{ [audioEngine toggleEffect:3]; }
- (void)effect4{ [audioEngine toggleEffect:4]; }
- (void)effect5{ [audioEngine toggleEffect:5]; }

- (void)record
{
    if (recordingStart == -1) {
        recordingStart = [audioEngine getBufferLength];
        NSString* pathToImageFile = [[NSBundle mainBundle] pathForResource:@"Stop" ofType:@"png"];
        [self.recordButton setImage:[[UIImage alloc] initWithContentsOfFile:pathToImageFile] forState:UIControlStateNormal];
    } else {
        recordingLength = [audioEngine getBufferLength] - recordingStart;
        [self upload];
    }
}


- (void)saveFile
{
    NSData *data = [audioEngine getAudioData:recordingStart withLength:recordingLength];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *appFile = [documentsDirectory stringByAppendingPathComponent:@"Recording.wav"];
    NSLog(@"Write to: %@", appFile);
    [data writeToFile:appFile atomically:YES];
    
    [self reset];
}

- (void)upload
{
    NSData *data = [audioEngine getAudioData:recordingStart withLength:recordingLength];
    
    SCShareViewController *shareViewController;
    shareViewController = [SCShareViewController 
                           shareViewControllerWithFileData:data
                           completionHandler:^(NSDictionary *trackInfo, NSError *error) {
                               if (SC_CANCELED(error)) {
                                   NSLog(@"Canceled!");
                                   [self reset];
                               } else if (error) {
                                   NSLog(@"Ooops, something went wrong: %@", [error localizedDescription]);
                                   [self reset];
                               } else {
                                   // If you want to do something with the uploaded
                                   // track this is the right place for that.
                                   NSLog(@"Uploaded track: %@", trackInfo);
                                   [self reset];
                               }
                           }];
    
    // We can preset the title ...
    [shareViewController setTitle:@"My new InstaSound"];
    
    // ... and other options like the private flag.
    [shareViewController setPrivate:YES];
    
    // Now present the share view controller.
    [self presentModalViewController:shareViewController animated:YES];
}

- (void)reset
{
    recordingStart = -1;
    recordingLength = -1;
    NSString* pathToImageFile = [[NSBundle mainBundle] pathForResource:@"Record" ofType:@"png"];
    [self.recordButton setImage:[[UIImage alloc] initWithContentsOfFile:pathToImageFile] forState:UIControlStateNormal];
}

- (void)dealloc {
	free(oscilLine);
}

- (void)drawOscilloscope {
    
	glClear(GL_COLOR_BUFFER_BIT);
    
	glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    
	glPushMatrix();
    
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
    
    int audioBufferLen = [audioEngine getBufferLength];
    Float32 *audioBuffer = [audioEngine getBuffer];
    
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
