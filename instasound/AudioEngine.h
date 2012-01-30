int initAudioEngine();

static OSStatus initAudioUnits();

static OSStatus initAudioGraph();

Float32 *getAudioBuffer();

int getAudioBufferLength();

static void toggleEffect1();
static void toggleEffect2();
static void toggleEffect3();
static void toggleEffect4();
static void toggleEffect5();

static OSStatus enableEffect1();
static OSStatus enableEffect2();
static OSStatus enableEffect3();
static OSStatus enableEffect4();
static OSStatus enableEffect5();

static OSStatus disableEffect1();
static OSStatus disableEffect2();
static OSStatus disableEffect3();
static OSStatus disableEffect4();
static OSStatus disableEffect5();

NSData *getAudioData(int offset, int length);

