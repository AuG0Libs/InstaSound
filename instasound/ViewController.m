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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

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
    
    NSString* pathToImageFile = [[NSBundle mainBundle] pathForResource:@"icon_Vinyl" ofType:@"png"];
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:pathToImageFile];
    UIBarButtonItem *effect1 = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(effect1)];
    [effect1 setTitle:@"effect1"];

    pathToImageFile = [[NSBundle mainBundle] pathForResource:@"icon_Vinyl" ofType:@"png"];
    image = [[UIImage alloc] initWithContentsOfFile:pathToImageFile];
    UIBarButtonItem *effect2 = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(effect2)];
    [effect2 setTitle:@"effect2"];

    [self.toolBar setItems:[NSArray arrayWithObjects: effect1, effect2, nil]];

    [self.view addSubview:self.toolBar];
}

- (void)initializeEAGL
{
    initAudioEngine();

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
    [self.recordButton addTarget:self action:@selector(saveFile) forControlEvents:UIControlEventTouchUpInside];

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

- (void)effect1{ toggleEffect1(); }
- (void)effect2{ toggleEffect2(); }
- (void)effect3{ toggleEffect3(); }
- (void)effect4{ toggleEffect4(); }
- (void)effect5{ toggleEffect5(); }

- (void)record
{
    [self.recordButton setHidden:TRUE];
}


- (void)saveFile
{
    NSData *data = getAudioData(0, getAudioBufferLength());
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *appFile = [documentsDirectory stringByAppendingPathComponent:@"MyFile.mp3"];
    NSLog(@"Write to: %@", appFile);
    [data writeToFile:appFile atomically:YES];
}

- (void)upload
{
//    NSString *mp3_filepath = [[NSBundle mainBundle] pathForResource:@"short_old" ofType:@"mp3"];
//    NSURL *trackURL = [NSURL fileURLWithPath: mp3_filepath];
    
    NSData *data = getAudioData(0, getAudioBufferLength());

    SCShareViewController *shareViewController;
    shareViewController = [SCShareViewController shareViewControllerWithFileData:data
                                                              completionHandler:^(NSDictionary *trackInfo, NSError *error) {
                                                                  if (SC_CANCELED(error)) {
                                                                      NSLog(@"Canceled!");
                                                                  } else if (error) {
                                                                      NSLog(@"Ooops, something went wrong: %@", [error localizedDescription]);
                                                                  } else {
                                                                      // If you want to do something with the uploaded
                                                                      // track this is the right place for that.
                                                                      NSLog(@"Uploaded track: %@", trackInfo);
                                                                  }
                                                              }];

    // We can preset the title ...
    [shareViewController setTitle:@"Funny sounds"];

    // ... and other options like the private flag.
    [shareViewController setPrivate:YES];

    // Now present the share view controller.
    [self presentModalViewController:shareViewController animated:YES];
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

    int audioBufferLen = getAudioBufferLength();
    Float32 *audioBuffer = getAudioBuffer();

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
