#import <UIKit/UIKit.h>

#import "EAGLView.h"

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#include <libkern/OSAtomic.h>
#include <CoreFoundation/CFURL.h>

@interface ViewController : UIViewController <EAGLViewDelegate>
{
    EAGLView* eaglView;
	GLfloat*  oscilLine;
}

@property (retain, nonatomic) IBOutlet UINavigationBar *navigationBar;
@property (retain, nonatomic) IBOutlet UITabBar *buttonBar;
@property (retain, nonatomic) EAGLView *eaglView;
@property (retain, nonatomic) IBOutlet UIButton *recordButton;

- (void)initializeNavigationView;
- (void)initializeButtons;
- (void)initializeEAGL;
- (void)initializeRecordButton;

- (void)record;

@end
