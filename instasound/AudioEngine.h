int initAudioEngine();

static OSStatus initAudioUnits();

static OSStatus initAudioGraph();

Float32 *getAudioBuffer();

int getAudioBufferLength();

NSData *getAudioData(int offset, int length);

id 
