#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#include <libkern/OSAtomic.h>
#include <CoreFoundation/CFURL.h>

#import "EAGLView.h"
#import "ViewController.h"

@interface AppDelegate : NSObject <UIApplicationDelegate, EAGLViewDelegate> {
	UIWindow* window;
	EAGLView* eaglView;
	GLfloat*  oscilLine;
}

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) ViewController *viewController;
@property (strong, nonatomic) EAGLView *eaglView;

@property (retain, nonatomic) IBOutlet UINavigationBar *navigationBar;
@property (retain, nonatomic) IBOutlet UITabBar *buttonBar;

- (void)initializeEAGLView;
- (void)initializeNavigationView;
- (void)initializeButtons;

@end

