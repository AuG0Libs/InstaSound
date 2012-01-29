#import "AudioEngine.h"
#import "AppDelegate.h"
#import "ViewController.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize eaglView = _eaglView;
@synthesize viewController = _viewController;
@synthesize navigationBar = _navigationBar;
@synthesize buttonBar = _buttonBar;
@synthesize recordButton = _recordButton;

int points = 1024;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Make it red to see size issues
    [self.window setBackgroundColor:[UIColor redColor]];

    initAudioEngine();
    
    [self initializeEAGLView];
    [self initializeNavigationView];
    [self initializeButtons];
    [self initializeRecordButton];
    
    [self.window addSubview:self.eaglView];
    [self.window addSubview:self.navigationBar];
    [self.window addSubview:self.buttonBar];
    [self.window addSubview:self.recordButton];

    // self.viewController.view = view;
    // self.window.rootViewController = self.viewController;

    [self.window makeKeyAndVisible];

    return YES;
}

- (void) initializeEAGLView
{
    oscilLine = (GLfloat*)malloc(points * 2 * sizeof(GLfloat));
       
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
- (void)initializeRecordButton
{
    self.recordButton = [[UIButton alloc] initWithFrame:CGRectMake(99, 171, 123, 123)];
    
    NSString* pathToImageFile = [[NSBundle mainBundle] pathForResource:@"Record" ofType:@"png"];
    [self.recordButton setImage:[[UIImage alloc] initWithContentsOfFile:pathToImageFile] forState:UIControlStateNormal];
    [self.recordButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentCenter];
    [self.recordButton setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
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
