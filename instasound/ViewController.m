//
//  ViewController.m
//  singleview
//
//  Created by matti on 29/01/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#import "SCUI.h"

@implementation ViewController

@synthesize navigationBar = _navigationBar;
@synthesize buttonBar = _buttonBar;
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
    NSLog(@"viewcontroller did load");
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
    
    UINavigationItem *title = [[UINavigationItem alloc] initWithTitle:@"InstaSound"];
    [self.navigationBar pushNavigationItem:title animated:true];
    [self.navigationBar sizeToFit];
    
    [self.view addSubview:self.navigationBar];
}

- (void)initializeButtons
{
    self.buttonBar = [[UITabBar alloc] initWithFrame:CGRectMake(0, 411, 320, 49)];
    
    NSString* pathToImageFile = [[NSBundle mainBundle] pathForResource:@"icon_Vinyl" ofType:@"png"];
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:pathToImageFile];
    UITabBarItem *church = [[UITabBarItem alloc] initWithTitle:@"Church" image:image tag:1];
    
    [self.buttonBar setItems:[NSArray arrayWithObjects: church, nil]];
    
    [self.view addSubview:self.buttonBar];
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
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    NSLog(@"willDisappear");
	[super viewWillDisappear:animated];
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

- (void)record
{
    NSLog(@"Test");
    NSString *mp3_filepath = [[NSBundle mainBundle] pathForResource:@"short_old" ofType:@"mp3"];
    NSURL *trackURL = [NSURL fileURLWithPath: mp3_filepath];
    
    SCShareViewController *shareViewController;
    shareViewController = [SCShareViewController shareViewControllerWithFileURL:trackURL 
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

- (void)activate
{
    self.eaglView.applicationResignedActive = YES;
    [self.eaglView stopAnimation];
}

- (void)deactivate
{
    self.eaglView.applicationResignedActive = NO;
    [self.eaglView startAnimation];
}


@end
