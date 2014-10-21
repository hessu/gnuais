
/*
 *	AudioUnit code for OS X
 */

#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioComponent.h>
#import <AudioUnit/AUComponent.h>
#import <AudioUnit/AudioUnitProperties.h>
#import <CoreAudio/AudioHardware.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <AudioUnit/AudioOutputUnit.h>

#include "../config.h"
#include "audiounit.h"
#include "hlog.h"
#include "hmalloc.h"

AudioComponentInstance auHAL;
AudioDeviceID inputDevice;

void hlog_nserr(int level, const char *msg, OSStatus err)
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];

	NSString *errstr = [error description]; // [error localizedDescription];
	const char *s = [errstr UTF8String];
	
	hlog(level, "%s: %s", msg, s);
}


/*
 *	Open up a device, this works on 10.6 and later
 */

static int audiounit_open(const char *device)
{
	AudioComponentDescription desc;
	AudioComponent comp;
	
	hlog(LOG_INFO, "Opening AudioUnit ...");
	
	//There are several different types of Audio Units.
	//Some audio units serve as Outputs, Mixers, or DSP
	//units. See AUComponent.h for listing
	desc.componentType = kAudioUnitType_Output;
	
	//Every Component has a subType, which will give a clearer picture
	//of what this components function will be.
	desc.componentSubType = kAudioUnitSubType_HALOutput;
	
	//all Audio Units in AUComponent.h must use 
	//"kAudioUnitManufacturer_Apple" as the Manufacturer
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	
	//Finds a component that meets the desc spec's
	comp = AudioComponentFindNext(NULL, &desc);
	if (comp == NULL)
		return -1;
	
	//gains access to the services provided by the component
	AudioComponentInstanceNew(comp, &auHAL);
	
	return 0;
}

static int audiounit_enable_input()
{
	UInt32 enableIO;
	OSStatus err = noErr;
	
	// When using AudioUnitSetProperty the 4th parameter in the method
	// refer to an AudioUnitElement. When using an AudioOutputUnit
	// the input element will be '1' and the output element will be '0'.
	
	enableIO = 1;
	err = AudioUnitSetProperty(auHAL,
		kAudioOutputUnitProperty_EnableIO,
		kAudioUnitScope_Input,
		1, // input element
		&enableIO,
		sizeof(enableIO));
	
	if (err) {
		hlog_nserr(LOG_ERR, "Failed to enable AudioUnit input", err);
		return err;
	}
	
	enableIO = 0;
	err = AudioUnitSetProperty(auHAL,
		kAudioOutputUnitProperty_EnableIO,
		kAudioUnitScope_Output,
		0,   //output element
		&enableIO,
		sizeof(enableIO));
		
	if (err) {
		hlog_nserr(LOG_ERR, "Failed to disable AudioUnit output", err);
		return err;
	}
	
	return err;
}

AudioStreamBasicDescription DeviceFormat = {0};

OSStatus audiounit_select_format()
{
	OSStatus err = noErr;
	UInt32 size = sizeof(DeviceFormat);
	
	AudioObjectPropertyAddress addr = {
		kAudioDevicePropertyStreamFormat,
		kAudioDevicePropertyScopeInput,
		0 };
	
	// Get the input device format
	err = AudioObjectGetPropertyData(inputDevice,
		&addr,
		0,
		NULL,
		&size,
		&DeviceFormat);
	
	if (err != noErr) {
		NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
		NSString *errstr = [error localizedDescription];
		const char *s = [errstr UTF8String];
		hlog(LOG_ERR, "Failed to get AudioUnit default format: %s", s);
		return -1;
	}
	
	hlog(LOG_DEBUG, "Sample rate is %.0f, %d bits, %d channels, %d bytes/frame",
		DeviceFormat.mSampleRate,
		DeviceFormat.mBitsPerChannel,
		DeviceFormat.mChannelsPerFrame,
		DeviceFormat.mBytesPerFrame);
	
	//set the desired format to the device's sample rate
	//DeviceFormat.mSampleRate = 8000.0;
	/*
	DeviceFormat.mFormatID = kAudioFormatLinearPCM;
	DeviceFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger; //kCAFLinearPCMFormatFlagIsLittleEndian;
	DeviceFormat.mChannelsPerFrame = 2;
	DeviceFormat.mBitsPerChannel = 16;
	DeviceFormat.mBytesPerFrame = DeviceFormat.mChannelsPerFrame*2;
	DeviceFormat.mFramesPerPacket = 1;
	DeviceFormat.mBytesPerPacket = DeviceFormat.mFramesPerPacket * DeviceFormat.mBytesPerFrame;
	*/
	err = AudioUnitSetProperty(
		auHAL,
		kAudioUnitProperty_StreamFormat,
		kAudioUnitScope_Input,
		0,
		&DeviceFormat,
		sizeof(AudioStreamBasicDescription));
	
	if (err) {
		hlog_nserr(LOG_ERR, "Failed to set AudioUnit default input device", err);
		return err;
	}

#define USING_OSX
#if defined ( USING_IOS )
	UInt32 numFramesPerBuffer;
	size = sizeof(UInt32);
	err = AudioUnitGetProperty(auHAL,
			kAudioUnitProperty_MaximumFramesPerSlice,
			kAudioUnitScope_Global,
			kOutputBus,
			&numFramesPerBuffer,
			&size);
	if (err) {
		hlog_nserr(LOG_ERR, "Couldn't get the number of frames per callback", err);
		return err;
	}
	UInt32 bufferSizeBytes = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket * numFramesPerBuffer;
    
#elif defined ( USING_OSX )
	// Get the size of the IO buffer(s)
	UInt32 bufferSizeFrames = 0;
	size = sizeof(UInt32);
	err = AudioUnitGetProperty(auHAL,
		kAudioDevicePropertyBufferFrameSize,
		kAudioUnitScope_Global,
		0,
		&bufferSizeFrames,
		&size);
	if (err) {
		hlog_nserr(LOG_ERR, "Couldn't get buffer frame size from input unit", err);
		return err;
	}
	//UInt32 bufferSizeBytes = bufferSizeFrames * sizeof(UInt16) *2;
#endif
	
	hlog(LOG_DEBUG, "Should set up a buffer of %d frames", bufferSizeFrames);
	
	// Set system buffer allocation
	UInt32 flag = 0;
	err = AudioUnitSetProperty(auHAL, kAudioUnitProperty_ShouldAllocateBuffer,
		kAudioUnitScope_Output, 
		1, &flag, sizeof(flag));
	if (err) {
		hlog_nserr(LOG_ERR, "Failed to set AudioUnit system buffering", err);
		return err;
	}

	hlog(LOG_DEBUG, "audiounit_select_format success");
	
	return err;
}

OSStatus audiounit_select_default_input()
{
	OSStatus err = noErr;
	UInt32 size = sizeof(AudioDeviceID);
	
	AudioObjectPropertyAddress theAddress = {
		kAudioHardwarePropertyDefaultInputDevice,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	err = AudioObjectGetPropertyData(kAudioObjectSystemObject,
		&theAddress,
		0,
		NULL,
		&size,
		&inputDevice);
	
	if (err) {
		hlog(LOG_ERR, "Failed to get AudioUnit default input device: %s", strerror(err));
		return err;
	}
	
	err = AudioUnitSetProperty(auHAL,
		kAudioOutputUnitProperty_CurrentDevice,
		kAudioUnitScope_Global,
		0,
		&inputDevice,
		sizeof(inputDevice));
	
	if (err != noErr)
		hlog(LOG_ERR, "Failed to set AudioUnit default input device: %s", strerror(err));
	
	return err;
}

AudioBufferList *bufferList; /* allocated to hold buffer data  */

OSStatus InputProc(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
	const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames,
	AudioBufferList * ioData)
{
	OSStatus err = noErr;
	SInt16 *sm1, *sm2;
	
	hlog(LOG_DEBUG, "InputProc inBusNumber %d inNumberFrames %d", inBusNumber, inNumberFrames);
	
	err = AudioUnitRender(auHAL,
		ioActionFlags,
		inTimeStamp, 
		inBusNumber,     // will be '1' for input data
		inNumberFrames, // # of frames requested
		bufferList);
	
	if (err != noErr)
		hlog_nserr(LOG_ERR, "AudioUnitRender failed", err);
	
	sm1 = (SInt16 *)bufferList->mBuffers[0].mData;
	sm2 = (SInt16 *)bufferList->mBuffers[1].mData;
	
	return err;
}

static OSStatus CheckErr(const char *s, OSStatus err)
{
	if (err != noErr)
		hlog_nserr(LOG_ERR, s, err);
	
	return err;
}

static void audiounit_allocate_buffer(void)
{
#define BUFFERS 2
	bufferList = (AudioBufferList*)hmalloc(sizeof(AudioBufferList)
		+ BUFFERS*sizeof(void *));
	bufferList->mNumberBuffers = BUFFERS;
	
	int bufferSize = 512 * DeviceFormat.mBytesPerFrame;
	
	int i;
	for (i = 0; i < BUFFERS; i++) {
		hlog(LOG_DEBUG, "Allocating buffer %d of %d bytes", i, bufferSize);
		bufferList->mBuffers[i].mDataByteSize = bufferSize;
		bufferList->mBuffers[i].mNumberChannels = DeviceFormat.mChannelsPerFrame;
		bufferList->mBuffers[i].mData = hmalloc(bufferSize);
		memset(bufferList->mBuffers[i].mData, 0, bufferSize);
	}	
}

OSStatus audiounit_input_callback_setup(void)
{
	OSStatus err = noErr;
	audiounit_allocate_buffer();
	
	AURenderCallbackStruct input;
	input.inputProc = InputProc;
	input.inputProcRefCon = 0;
	
	err = AudioUnitSetProperty(
		auHAL, 
		kAudioOutputUnitProperty_SetInputCallback, 
		kAudioUnitScope_Global,
		0,
		&input, 
		sizeof(input));
	if (err)
		return err;
		
	err = AudioUnitInitialize(auHAL);
	if (err)
		return err;
	
	hlog(LOG_DEBUG, "AudioOutputUnitStart");
	err = AudioOutputUnitStart(auHAL);
	
	return err;
}
	

int audiounit_initialize(const char *device)
{
	
	if (audiounit_open(device) < 0)
		return -1;
	
	if (audiounit_enable_input() < 0)
		return -1;
	
	if (audiounit_select_default_input() != noErr)
		return -1;
	
	if (audiounit_select_format() != noErr)
		return -1;
	
	if (audiounit_select_format() != noErr)
		return -1;
	
	if (audiounit_input_callback_setup() != noErr)
		return -1;
	
	hlog(LOG_DEBUG, "audiounit initialized");
	
	return 0;
}

int audiounit_read(short *buffer, int len)
{
	return 0;
}

