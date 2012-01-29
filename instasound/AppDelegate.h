
#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#include <libkern/OSAtomic.h>
#include <CoreFoundation/CFURL.h>

#import "EAGLView.h"
#import "ViewController.h"
#import "AudioToolbox/AudioToolbox.h"

#define SPECTRUM_BAR_WIDTH 4

#ifndef CLAMP
#define CLAMP(min,x,max) (x < min ? min : (x > max ? max : x))
#endif

inline double linearInterp(double valA, double valB, double fract)
{
	return valA + ((valB - valA) * fract);
}

@interface AppDelegate : NSObject <UIApplicationDelegate, EAGLViewDelegate> {
	UIWindow*                   window;
	EAGLView*                   view;
    
	AudioUnit					mixerUnit;
    AudioUnit                   ioUnit;
    AudioUnit                   output;
    AUGraph                     graph;
	BOOL						unitIsRunning;
	BOOL						unitHasBeenCreated;
	UInt32*						texBitBuffer;
	
    AudioStreamBasicDescription	ioFormat;
	GLfloat*					oscilLine;
}


@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ViewController *viewController;

@property (strong, nonatomic)	EAGLView*				view;

@property (nonatomic, assign)	BOOL						unitIsRunning;
@property (nonatomic, assign)	BOOL						unitHasBeenCreated;


@end
