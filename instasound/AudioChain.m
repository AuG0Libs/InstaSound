#import "AudioChain.h"

@implementation AudioChain

+ (AudioChain *) create:(NSArray *)units
{
    AudioChain *chain = [[self alloc] init];
    chain.units = units;
    return chain;
}

- (AudioChain *) connect:(IAudioUnit *)input with:(IAudioUnit *)output on:(int)channel
{
    int count = [_units count];
    
    if (count == 0) {
        return self;
    }
    
    [input connectTo:_units[0] from:0 to:0];

    for (int i = 0; i < count - 1; i++) {
        [_units[i] connectTo:_units[i + 1] from:0 to:0];
    }

    [_units[count - 1] connectTo:output from:0 to:channel];

    return self;
}

- (AudioChain *) disconnect:(IAudioUnit *)input with:(IAudioUnit *)output
{
    int count = [_units count];
    
    if (count == 0) {
        return self;
    }
    
    [input disconnectFrom:_units[0]];

    for (int i = 0; i < count - 1; i++) {
        [_units[i] disconnectFrom:_units[i + 1]];
    }

    [_units[count - 1] disconnectFrom:output];
    
    return self;
}

@end
