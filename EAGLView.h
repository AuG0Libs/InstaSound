
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

@protocol EAGLViewDelegate
@required
- (void)drawView:(id)sender forTime:(NSTimeInterval)time;
@optional
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
@end

@interface EAGLView : UIView
{
@private

	GLint backingWidth;
	GLint backingHeight;

	EAGLContext *context;

	GLuint viewRenderbuffer, viewFramebuffer;

	GLuint depthRenderbuffer;

	GLuint bgTexture;

	id <EAGLViewDelegate> delegate;

	NSTimer *animationTimer;
	NSTimeInterval animationInterval;
	NSTimeInterval animationStarted;

    BOOL applicationResignedActive;
}

- (void)startAnimation;
- (void)stopAnimation;
- (void)drawView;

@property NSTimeInterval animationInterval;
@property(assign) id <EAGLViewDelegate> delegate;
@property(assign) BOOL applicationResignedActive;

@end
