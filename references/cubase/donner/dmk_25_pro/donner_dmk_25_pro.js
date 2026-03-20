//-----------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//-----------------------------------------------------------------------------

// get the api's entry point
var midiremote_api = require("midiremote_api_v1");

// create the device driver main object
var deviceDriver = midiremote_api.makeDeviceDriver(
  "Donner",
  "DMK-25 Pro",
  "Ration technology"
);

// create objects representing the hardware's MIDI ports
var midiInput = deviceDriver.mPorts.makeMidiInput();
var midiOutput = deviceDriver.mPorts.makeMidiOutput();

// define all possible namings the devices MIDI ports could have
// NOTE: Windows and MacOS handle port naming differently
deviceDriver
  .makeDetectionUnit()
  .detectPortPair(midiInput, midiOutput)
  .expectInputNameEquals("DONNER DMK25Pro")
  .expectOutputNameEquals("DONNER DMK25Pro");

var surface = deviceDriver.mSurface;
var knobControlLayerZone = surface.makeControlLayerZone("Knob Bank");
var knobcontrolLayerControlBankA =
  knobControlLayerZone.makeControlLayer("Knob Bank A");
var knobcontrolLayerControlBankB =
  knobControlLayerZone.makeControlLayer("Knob Bank B");
var knobcontrolLayerControlBankC =
  knobControlLayerZone.makeControlLayer("Knob Bank C");

var padControlLayerZone = surface.makeControlLayerZone("pad Bank");
var padcontrolLayerControlBankA =
  padControlLayerZone.makeControlLayer("pad BankA");
var padcontrolLayerControlBankB =
  padControlLayerZone.makeControlLayer("pad BankB");
var padcontrolLayerControlBankC =
  padControlLayerZone.makeControlLayer("pad BankC");

var faderControlLayerZone = surface.makeControlLayerZone("fader Bank");
var fadercontrolLayerControlBankA =
  faderControlLayerZone.makeControlLayer("fader BankA");
var fadercontrolLayerControlBankB =
  faderControlLayerZone.makeControlLayer("fader BankB");
var fadercontrolLayerControlBankC =
  faderControlLayerZone.makeControlLayer("fader BankC");
//-----------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//-----------------------------------------------------------------------------
// create control element representing your hardware's surface
//创建PAD按钮
function Make_Pads(ccNrA, ccNrB, ccNrC) {
  var pads = {};
  pads.padA = [];
  pads.padB = [];
  pads.padC = [];
  for (var i = 0; i < 2; i++) {
    for (var j = 0; j < 4; j++) {
      var pad = surface
        .makeTriggerPad(j * 3 + 4, 3 * (1 - i), 3, 3)
        .setControlLayer(padcontrolLayerControlBankA);
      pad.mSurfaceValue.mMidiBinding
        .setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToControlChange(9, ccNrA + j + 4 * i);
      pads.padA.push(pad);
      var pad = surface
        .makeTriggerPad(j * 3 + 4, 3 * (1 - i), 3, 3)
        .setControlLayer(padcontrolLayerControlBankB);
      pad.mSurfaceValue.mMidiBinding
        .setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToControlChange(9, ccNrB + j + 4 * i);
      pads.padA.push(pad);
      var pad = surface
        .makeTriggerPad(j * 3 + 4, 3 * (1 - i), 3, 3)
        .setControlLayer(padcontrolLayerControlBankC);
      pad.mSurfaceValue.mMidiBinding
        .setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToControlChange(9, ccNrC + j + 4 * i);
      pads.padA.push(pad);
    }
  }
  return pads;
}
function Make_Knob(ccNrA, ccNrB, ccNrC) {
  //创建旋钮
  var knobs = {};
  knobs.knobA = [];
  knobs.knobB = [];
  knobs.knobC = [];

  for (var i = 0; i < 4; i++) {
    //界面A创建
    //创建按钮
    var knob = surface
      .makeKnob(i * 2 + 22, 0, 2, 2)
      .setControlLayer(knobcontrolLayerControlBankA);
    knob.mSurfaceValue.mMidiBinding
      .setInputPort(midiInput)
      .setOutputPort(midiOutput)
      .bindToControlChange(0, ccNrA + i);
    knobs.knobA.push(knob);

    //界面B创建
    //创建按钮
    var knob = surface
      .makeKnob(i * 2 + 22, 0, 2, 2)
      .setControlLayer(knobcontrolLayerControlBankB);
    knob.mSurfaceValue.mMidiBinding
      .setInputPort(midiInput)
      .setOutputPort(midiOutput)
      .bindToControlChange(0, ccNrB + i);
    knobs.knobB.push(knob);

    //创建界面C
    //创建按钮
    var knob = surface
      .makeKnob(i * 2 + 22, 0, 2, 2)
      .setControlLayer(knobcontrolLayerControlBankC);
    knob.mSurfaceValue.mMidiBinding
      .setInputPort(midiInput)
      .setOutputPort(midiOutput)
      .bindToControlChange(0, ccNrC + i);
    knobs.knobC.push(knob);
  }
  return knobs;
}
function Make_Fader(chNrA, chNrB, chNrC) {
  //创建滑动条
  var faders = {};
  faders.faderA = [];
  faders.faderB = [];
  faders.faderC = [];
  for (var i = 0; i < 4; i++) {
    //界面A创建
    //创建滑动条
    var fader = surface
      .makeFader(i * 2 + 22, 2.8, 2, 6)
      .setControlLayer(fadercontrolLayerControlBankA);
    fader.mSurfaceValue.mMidiBinding
      .setInputPort(midiInput)
      .setOutputPort(midiOutput)
      .bindToControlChange(chNrA + i, 7);
    faders.faderA.push(fader);

    //界面B创建
    //创建滑动条
    var fader = surface
      .makeFader(i * 2 + 22, 2.8, 2, 6)
      .setControlLayer(fadercontrolLayerControlBankB);
    fader.mSurfaceValue.mMidiBinding
      .setInputPort(midiInput)
      .setOutputPort(midiOutput)
      .bindToControlChange(chNrB + i, 7);
    faders.faderB.push(fader);

    //创建界面C
    //创建滑动条
    var fader = surface
      .makeFader(i * 2 + 22, 2.8, 2, 6)
      .setControlLayer(fadercontrolLayerControlBankC);
    fader.mSurfaceValue.mMidiBinding
      .setInputPort(midiInput)
      .setOutputPort(midiOutput)
      .bindToControlChange(chNrC + i, 7);
    faders.faderC.push(fader);
  }
  return faders;
}
//创建pad按钮
var pads = Make_Pads(36, 44, 52);
//创建旋钮
var knobs = Make_Knob(30, 34, 38);
//创建滑条
var faders = Make_Fader(0, 4, 8);
//创建钢琴键盘
var pianoKey = surface.makePianoKeys(0, 9.5, 30.5, 7, 0, 24);
//创建弯音bend
var PitchBend = surface.makePitchBend(0, 0, 1.5, 8);
//绑定弯音bend输入
PitchBend.mSurfaceValue.mMidiBinding
  .setInputPort(midiInput)
  .setOutputPort(midiOutput)
  .bindToPitchBend(0);
//创建modwheel
var ModWheel = surface.makeModWheel(1.5, 0, 1.5, 8);
//绑定modwheel输入
ModWheel.mSurfaceValue.mMidiBinding
  .setInputPort(midiInput)
  .setOutputPort(midiOutput)
  .bindToControlChange(0, 1);

//创建底部横排按钮
var button_H = [];
for (var i = 0; i < 6; i++) {
  var button = surface.makeButton(i * 2 + 4, 7.5, 2, 1);
  button.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0, i + 15);
  button_H.push(button);
}
//创建右边竖排按钮
var button_V = [];
for (var i = 0; i < 4; i++) {
  for (var j = 0; j < 2; j++) {
    if (i == 3) var button = surface.makeButton(j * 2.3 + 16.8, i + 4.5, 2, 1);
    else var button = surface.makeButton(j * 2.3 + 16.8, i + 4, 2, 1);
    button_V.push(button);
  }
}

surface.makeBlindPanel(16.5, 0, 5, 3.5);
var page = deviceDriver.mMapping.makePage("Main Page");
page
  .makeValueBinding(
    button_H[0].mSurfaceValue,
    page.mHostAccess.mTransport.mValue.mCycleActive
  )
  .setTypeToggle();
page
  .makeValueBinding(
    button_H[1].mSurfaceValue,
    page.mHostAccess.mTransport.mValue.mRewind
  )
  .setTypeDefault();
page
  .makeValueBinding(
    button_H[2].mSurfaceValue,
    page.mHostAccess.mTransport.mValue.mForward
  )
  .setTypeDefault();
page
  .makeValueBinding(
    button_H[3].mSurfaceValue,
    page.mHostAccess.mTransport.mValue.mStop
  )
  .setTypeDefault();
page
  .makeValueBinding(
    button_H[4].mSurfaceValue,
    page.mHostAccess.mTransport.mValue.mStart
  )
  .setTypeDefault();
page
  .makeValueBinding(
    button_H[5].mSurfaceValue,
    page.mHostAccess.mTransport.mValue.mRecord
  )
  .setTypeDefault();
// var hostMixerBankZone = page.mHostAccess.mMixConsole
//   .makeMixerBankZone()
//   .excludeInputChannels()
//   .excludeOutputChannels();
// var channelBankItem = hostMixerBankZone.makeMixerBankChannel();

// page.makeValueBinding(ModWheel.mSurfaceValue, channelBankItem.mValue.mVolume);
