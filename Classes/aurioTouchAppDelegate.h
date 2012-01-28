
#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#include <libkern/OSAtomic.h>
#include <CoreFoundation/CFURL.h>

#import "EAGLView.h"
#import "aurio_helper.h"
#import "CAStreamBasicDescription.h"
#import "AudioUnit/AudioUnit.h"

#define SPECTRUM_BAR_WIDTH 4

#ifndef CLAMP
#define CLAMP(min,x,max) (x < min ? min : (x > max ? max : x))
#endif

inline double linearInterp(double valA, double valB, double fract)
{
	return valA + ((valB - valA) * fract);
}

@interface aurioTouchAppDelegate : NSObject <UIApplicationDelegate, EAGLViewDelegate> {
	IBOutlet UIWindow*			window;
	IBOutlet EAGLView*			view;
    
	AudioUnit					rioUnit;
	BOOL						unitIsRunning;
	BOOL						unitHasBeenCreated;
	UInt32*						texBitBuffer;
	
	CAStreamBasicDescription	thruFormat;
	Float64						hwSampleRate;
	
	AURenderCallbackStruct		inputProc;
	
	int32_t*					l_fftData;

	GLfloat*					oscilLine;
	BOOL						resetOscilLine;
}

@property (nonatomic, retain)	UIWindow*				window;
@property (nonatomic, retain)	EAGLView*				view;

@property (nonatomic, assign)	AudioUnit				rioUnit;
@property (nonatomic, assign)	BOOL						unitIsRunning;
@property (nonatomic, assign)	BOOL						unitHasBeenCreated;
@property (nonatomic, assign)	AURenderCallbackStruct	inputProc;

@end

