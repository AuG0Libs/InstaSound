int initAudioEngine();

OSStatus initAudioUnits();

OSStatus initAudioGraph();

Float32 *getAudioBuffer();

int getAudioBufferLength();

NSData *getAudioData(int offset, int length);

void toggleEffect1();
void toggleEffect2();
void toggleEffect3();
void toggleEffect4();
void toggleEffect5();
