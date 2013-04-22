
/*
 *	AudioUnit code for OS X
 */

#include <AudioUnit/AudioComponent.h>
#include <AudioUnit/AUComponent.h>
#include <AudioUnit/AudioUnitProperties.h>
#include <CoreAudio/AudioHardware.h>

#include "../config.h"
#include "audiounit.h"
#include "hlog.h"

AudioComponentInstance auHAL;

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

OSStatus audiounit_select_default_input()
{
	UInt32 size;
	OSStatus err = noErr;
	AudioDeviceID inputDevice;
	size = sizeof(AudioDeviceID);
	
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
	
	return 0;
}
