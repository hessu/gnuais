
/*
 *	AudioUnit code for OS X
 */

#include <AudioUnit/AudioComponent.h>
#include <AudioUnit/AUComponent.h>

int audiounit_open(void)
{
	AudioComponent comp;
	AudioComponentDescription desc;
	AudioComponentInstance auHAL;
	
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
	if (comp == NULL) exit (-1);
	
	//gains access to the services provided by the component
	AudioComponentInstanceNew(comp, &auHAL);
	
	return 0;
}
