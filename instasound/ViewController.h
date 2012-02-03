#import <UIKit/UIKit.h>

#import "EAGLView.h"

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "AudioEngine.h"

#include <libkern/OSAtomic.h>
#include <CoreFoundation/CFURL.h>

@interface ViewController : UIViewController <EAGLViewDelegate>
{
    EAGLView* eaglView;
	GLfloat*  oscilLine;
    AudioEngine *audioEngine;
}

@property (retain, nonatomic) IBOutlet UINavigationBar *navigationBar;
@property (retain, nonatomic) IBOutlet UIToolbar *toolBar;
@property (retain, nonatomic) EAGLView *eaglView;
@property (retain, nonatomic) IBOutlet UIButton *recordButton;

- (void)initializeNavigationView;
- (void)initializeButtons;
- (void)initializeEAGL;
- (void)initializeRecordButton;

- (void)effect1;
- (void)effect2;
- (void)effect3;
- (void)effect4;
- (void)effect5;

- (void)record;
- (void)upload;
- (void)saveFile;
- (void)reset;

@end
