int initAudioEngine();

OSStatus initAudioUnits();

OSStatus initAudioGraph();

Float32 *getAudioBuffer();

int getAudioBufferLength();

NSData *getAudioData(int offset, int length);

id 
