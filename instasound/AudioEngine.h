int initAudioEngine();

OSStatus initAudioUnits();

OSStatus initAudioGraph();

Float32 *getAudioBuffer();

int getAudioBufferLength();

void toggleEffect1();
void toggleEffect2();
void toggleEffect3();
void toggleEffect4();
void toggleEffect5();

OSStatus enableEffect1();
OSStatus enableEffect2();
OSStatus enableEffect3();
OSStatus enableEffect4();
OSStatus enableEffect5();

OSStatus disableEffect1();
OSStatus disableEffect2();
OSStatus disableEffect3();
OSStatus disableEffect4();
OSStatus disableEffect5();

NSData *getAudioData(int offset, int length);

