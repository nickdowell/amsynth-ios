//
//  SynthHoster.m
//  amsynth
//
//  Created by Nick Dowell on 18/05/2013.
//  Copyright (c) 2013 Nick Dowell. All rights reserved.
//

#import "SynthHoster.h"

#import "PresetController.h"
#import "VoiceAllocationUnit.h"

#include <AssertMacros.h>
#include <AudioToolbox/AudioToolbox.h>

#define kOutputBus 0
//#define kInputBus 1
#define checkStatus check_noerr

static AudioUnit CreateAudioUnit(void *renderContext);
static OSStatus RenderCallback(void *inRefCon,
							   AudioUnitRenderActionFlags *ioActionFlags,
							   const AudioTimeStamp *inTimeStamp,
							   UInt32 inBusNumber,
							   UInt32 inNumberFrames,
							   AudioBufferList *ioData);

#pragma mark -

@interface SynthHoster ()
{
@public
	AudioUnit _audioUnit;
	float *_bufferL;
	float *_bufferR;
	PresetController *_presetController;
	VoiceAllocationUnit *_voiceAllocationUnit;
	NSMutableSet *_notesPlaying;
}

@end

@implementation SynthHoster

- (id)init
{
	if ((self = [super init])) {
		_audioUnit = CreateAudioUnit((__bridge void *)(self));
		_bufferL = (float *)malloc(sizeof(float) * 4096);
		_bufferR = (float *)malloc(sizeof(float) * 4096);
		_voiceAllocationUnit = new VoiceAllocationUnit();
		_voiceAllocationUnit->SetSampleRate(44100);
		_voiceAllocationUnit->SetMaxVoices(8);
		std::vector<BankInfo> banks = PresetController::getPresetBanks();
		NSMutableArray *names = [NSMutableArray array];
		for (size_t i=0; i<banks.size(); i++) {
			[names addObject:[NSString stringWithFormat:@"[%s] %s", banks[i].read_only ? "factory" : "user", banks[i].name.c_str()]];
		}
		_bankNames = [names copy];
		_presetController = new PresetController();
		_presetController->loadPresets(banks[0].file_path.c_str());
		_presetController->getCurrentPreset().AddListenerToAll(_voiceAllocationUnit);
		_presetController->selectPreset(0);
		[self updatePresetNames];
		_notesPlaying = [NSMutableSet set];
	}
	return self;
}

- (void)dealloc
{
	delete _voiceAllocationUnit;
	free(_bufferL);
	free(_bufferR);
}

- (void)start
{
	AudioOutputUnitStart(_audioUnit);
}

- (void)noteDown:(NSUInteger)note velocity:(float)velocity
{
	_voiceAllocationUnit->HandleMidiNoteOn(note, velocity);
	[_notesPlaying addObject:@(note)];
}

- (void)noteUp:(NSUInteger)note velocity:(float)velocity
{
	_voiceAllocationUnit->HandleMidiNoteOff(note, velocity);
	[_notesPlaying removeObject:@(note)];
}

- (void)setCurrentBankIndex:(NSUInteger)currentBankIndex
{
	_currentBankIndex = currentBankIndex;
	std::vector<BankInfo> banks = PresetController::getPresetBanks();
	_presetController->loadPresets(banks[currentBankIndex].file_path.c_str());
	_presetController->selectPreset(_currentPresetIndex);
	[self updatePresetNames];
}

- (void)setCurrentPresetIndex:(NSUInteger)currentPresetIndex
{
	_currentPresetIndex = currentPresetIndex;
	_voiceAllocationUnit->HandleMidiAllSoundOff();
	_presetController->selectPreset(currentPresetIndex);
	for (NSNumber *note in _notesPlaying)
		_voiceAllocationUnit->HandleMidiNoteOn([note intValue], 1);
}

- (void)updatePresetNames
{
	NSMutableArray *names = [NSMutableArray array];
	for (size_t i=0; i<PresetController::kNumPresets; i++) {
		const Preset &preset = _presetController->getPreset(i);
		[names addObject:[NSString stringWithFormat:@"%02zd: %s", i, preset.getName().c_str()]];
	}
	_presetNames = [names copy];
}

@end

#pragma mark -

static short sample_float_to_sint16(float flt) __attribute__((always_inline));
static short sample_float_to_sint16(float flt) { return (short)(flt * (float)SHRT_MAX); }

static AudioUnit CreateAudioUnit(void *renderContext)
{
	OSStatus status;
	AudioComponent component;
	AudioComponentInstance audioUnit;

	AudioComponentDescription audioComponentDescription = {
		.componentType = kAudioUnitType_Output,
		.componentSubType = kAudioUnitSubType_RemoteIO,
		.componentFlags = 0,
		.componentFlagsMask = 0,
		.componentManufacturer = kAudioUnitManufacturer_Apple
	};
	component = AudioComponentFindNext(NULL, &audioComponentDescription);

	status = AudioComponentInstanceNew(component, &audioUnit);
	checkStatus(status);

	UInt32 enableIO = 1;
	status = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &enableIO, sizeof(enableIO));
	checkStatus(status);

	UInt32 numChannels = 2;
	Float64 sampleRate = 44100;
	UInt32 bytesPerSample = sizeof(SInt16);
	AudioStreamBasicDescription streamDescription = {
		.mSampleRate = sampleRate,
		.mFormatID = kAudioFormatLinearPCM,
		.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
		.mBytesPerPacket = bytesPerSample * numChannels,
		.mFramesPerPacket = 1,
		.mBytesPerFrame = bytesPerSample * numChannels,
		.mChannelsPerFrame = numChannels,
		.mBitsPerChannel = bytesPerSample * 8,
	};
	status = AudioUnitSetProperty(audioUnit,
								  kAudioUnitProperty_StreamFormat,
								  kAudioUnitScope_Input,
								  kOutputBus,
								  &streamDescription, sizeof(streamDescription));
	checkStatus(status);


	AURenderCallbackStruct renderCallback = {
		.inputProc = RenderCallback,
		.inputProcRefCon = renderContext
	};
	status = AudioUnitSetProperty(audioUnit,
								  kAudioUnitProperty_SetRenderCallback,
								  kAudioUnitScope_Global,
								  kOutputBus,
								  &renderCallback, sizeof(renderCallback));
	checkStatus(status);

	status = AudioUnitInitialize(audioUnit);
	checkStatus(status);

	return audioUnit;
}

static OSStatus RenderCallback(void *inRefCon,
							   AudioUnitRenderActionFlags *ioActionFlags,
							   const AudioTimeStamp *inTimeStamp,
							   UInt32 inBusNumber,
							   UInt32 inNumberFrames,
							   AudioBufferList *ioData)
{
	SynthHoster *hoster = (__bridge id)inRefCon;

	hoster->_voiceAllocationUnit->Process(hoster->_bufferL, hoster->_bufferR, inNumberFrames);

	SInt16 *outBuffer = (SInt16 *)ioData->mBuffers[0].mData;
	for (size_t i=0; i<inNumberFrames; i++) {
		outBuffer[2 * i + 0] = sample_float_to_sint16(hoster->_bufferL[i]);
		outBuffer[2 * i + 1] = sample_float_to_sint16(hoster->_bufferR[i]);;
	}

	return noErr;
}

#pragma mark -

std::string PresetController::getFactoryBanksDirectory()
{
	return std::string([[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"banks"] UTF8String]);
}
