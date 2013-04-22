
/*
 *	AudioUnit code for OS X
 */

#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioComponent.h>
#import <AudioUnit/AUComponent.h>
#import <AudioUnit/AudioUnitProperties.h>
#import <CoreAudio/AudioHardware.h>
//#import <CoreServices/Debugging.h>

#include "../config.h"
#include "audiounit.h"
#include "hlog.h"

AudioComponentInstance auHAL;
AudioDeviceID inputDevice;

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
	
	// When using AudioUnitSetProperty the 4th parameter in the method
	// refer to an AudioUnitElement. When using an AudioOutputUnit
	// the input element will be '1' and the output element will be '0'.
	
	enableIO = 1;
	AudioUnitSetProperty(auHAL,
		kAudioOutputUnitProperty_EnableIO,
		kAudioUnitScope_Input,
		1, // input element
		&enableIO,
		sizeof(enableIO));
	
	enableIO = 0;
	AudioUnitSetProperty(auHAL,
		kAudioOutputUnitProperty_EnableIO,
		kAudioUnitScope_Output,
		0,   //output element
		&enableIO,
		sizeof(enableIO));
	
	
	return 0;
}

OSStatus audiounit_select_format()
{
	OSStatus err = noErr;
	AudioStreamBasicDescription DesiredFormat = {0};
	AudioStreamBasicDescription DeviceFormat = {0};
	UInt32 size = sizeof(DeviceFormat);
	
	AudioObjectPropertyAddress addr = {
		kAudioDevicePropertyStreamFormat,
		kAudioDevicePropertyScopeInput,
		inputDevice };
	
	// Get the input device format
	err = AudioObjectGetPropertyData(kAudioObjectSystemObject,
		&addr,
		0,
		NULL,
		&size,
		&DeviceFormat);
	
	if (err != noErr) {
		//NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
		//hlog(LOG_ERR, "Failed to get AudioUnit default format: %s", GetMacOSStatusErrorString(err));
		return -1;
	}
	
	//set the desired format to the device's sample rate
	DesiredFormat.mSampleRate =  44100;
	
	//set format to output scope
	err = AudioUnitSetProperty(
		auHAL,
		kAudioUnitProperty_StreamFormat,
		kAudioUnitScope_Output,
		1,
		&DesiredFormat,
		sizeof(AudioStreamBasicDescription));
	
	/*if (err)
		hlog(LOG_ERR, "Failed to set AudioUnit default input device: %s", GetMacOSStatusErrorString(err));
	*/
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
	
	if (err)
		hlog(LOG_ERR, "Failed to set AudioUnit default input device: %s", strerror(err));
	
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
	
	hlog(LOG_DEBUG, "audiounit initialized");
	
	return 0;
}
