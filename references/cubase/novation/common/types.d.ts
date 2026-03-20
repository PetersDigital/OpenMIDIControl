declare namespace Common {
  type Config = {
    appName: string;
    deviceDriver: MR_DeviceDriver;
    midiInput: MR_DeviceMidiInput;
    midiOutput: MR_DeviceMidiOutput;
    pid1: number;
    pid2: number;
    maxEncoderModes: number;
    maxFaderModes: number;
    maxSendSlots: number;
    numChannels: number;
    displayPriorityTimeout: number;
    eqAutoOnTimeout: number;
    hasIdleCallbacks: boolean;
    updateDisplayAtIdleTime: boolean;
    permanentDisplayTarget: number;
    overlayDisplayTarget: number;
  };

  /** Mixer bank zone */
  type MixerBankZone = {
    /** Control layer zone */
    zone: MR_MixerBankZone;
    /** Array of mixer bank channels */
    channels: MR_MixerBankChannel[];
  };

  /** Control layer zone */
  type ControlLayerZone = {
    /** Normal layer */
    defaultLayer: MR_Layer;
    /** Alt layer */
    altLayer: MR_Layer;
  };

  type IncDecEncoder = {
    incValue: MR_SurfaceCustomValueVariable;
    decValue: MR_SurfaceCustomValueVariable;
    bindToControlChange(
      channel: number,
      cc: number
    ): MR_MidiBindingToControlChange;
    onProcessValueChange?(
      activeDevice: MR_ActiveDevice,
      value: number,
      diff: number
    ): void;
  };

  type IncDecCommandBinding = {
    commandCategory: string;
    commandName: {inc: string; dec: string};
    display: {title: string; inc: string; dec: string};
  };

  type ToggleEncoder = {
    customValueVariable: MR_SurfaceCustomValueVariable;
    bindToControlChange(
      channel: number,
      cc: number
    ): MR_MidiBindingToControlChange;
  };

  type Rgb = [number, number, number];

  type ChannelSettings = {
    offset: number;
    r: number;
    g: number;
    b: number;
    isActive: boolean;
    hasValueTitle: boolean;
  };

  type SubPages = {
    makeSubPageArea(subPageAreaName: string): {
      /**
       * Invoked when a sub page is activated.
       * @param config - The configuration object.
       * @param device - The active device.
       * @param name - The name of the sub page.
       */
      onActivate: (
        config: Common.Config,
        device: MR_ActiveDevice,
        name: string
      ) => void | null;

      /**
       * Make a sub page
       * @param subPageName The name of the sub page to create.
       * @param subSection The name of the sub section.
       */
      makeSubPage(subPageName: string, subSection?: string): MR_SubPage;
    };

    /**
     * Look up a sub page.
     * @param subPageAreaName The name of the sub page area.
     * @param subPageName The name of the sub page.
     */
    lookup(
      subPageAreaName: string,
      subPageName: string
    ): MR_SubPage | undefined;
  };

  type ShiftSubPage = {
    shifted: MR_SubPage;
    unshifted: MR_SubPage;
  };
}

declare namespace LaunchkeyMk4 {
  type Config = Common.Config & {
    layoutConfig: LayoutConfig;
    maxPadModes: number;
  };

  type LayoutConfig = {
    leftGap: number;
    hasFaders: boolean;
    keys: number;
    keyMultiplier: number;
    isMini: boolean;
  };

  type ShiftableZone = {
    normalLayer: MR_Layer;
    shiftLayer: MR_Layer;
  };

  type UserInterface = {
    shiftableZone: ShiftableZone;
    trackButtons: TrackButtons;
    faderSection?: FaderSection;
    padSection: PadSection;
    encoderSection: EncoderSection;
    encoderModes: MR_SurfaceCustomValueVariable[];
    legacyEncoderModes: MR_SurfaceCustomValueVariable[];
    transportSection: TransportSection;
  };

  type VerticalButtons = {
    top: MR_Button;
    bottom: MR_Button;
  };

  type TrackButtons = {
    shift: MR_Button;
    legacyShift: MR_Button;
    trackPrev: MR_Button;
    trackNext: MR_Button;
    trackPrevShift: MR_Button;
    trackNextShift: MR_Button;
  };

  type FaderSection = {
    faders: MR_Fader[];
    buttons: MR_Button[];
    masterFader: MR_Fader;
    armSelect: MR_Button;
    faderModes: MR_SurfaceCustomValueVariable[];
    legacyFaderModes: MR_SurfaceCustomValueVariable[];
    labelFieldFaders: MR_SurfaceLabelField;
  };

  type PadSection = {
    upperPads: MR_TriggerPad[];
    lowerPads: MR_TriggerPad[];
    modeButtons: VerticalButtons;
    modeButtonsShift: VerticalButtons;
    padModes: MR_SurfaceCustomValueVariable[];
    legacyPadModes: MR_SurfaceCustomValueVariable[];
  };

  type EncoderSection = {
    encoders: MR_Knob[];
    labelFieldEncoders: MR_SurfaceLabelField;
    modeButtons: VerticalButtons;
  };

  type TransportSection = {
    captureMidi: MR_Button;
    undo: MR_Button;
    quantize: MR_Button;
    metronome: MR_Button;
    stop: MR_Button;
    cycle: MR_Button;
    play: MR_Button;
    record: MR_Button;
    zoom: Common.IncDecEncoder;
    marker: Common.IncDecEncoder;
  };

  type SubPages = Common.SubPages & {
    Encoders?: Record<string, MR_SubPage> & {
      ['Quick Controls']: MR_SubPage;
      Volume: MR_SubPage;
      Pan: MR_SubPage;
      EQ: MR_SubPage;
      Sends: MR_SubPage[];
      Transport: MR_SubPage;
      Other: MR_SubPage;
    };
    Faders?: {
      Volume: MR_SubPage;
      Other: MR_SubPage;
    };
    ['Fader Buttons']?: {
      Arm: MR_SubPage;
      Select: MR_SubPage;
    };
    Pads?: {
      ['Select / Arm']: MR_SubPage;
      ['Mute / Solo']: MR_SubPage;
      Other: MR_SubPage;
    };
    Shift?: ShiftSubPage;
  };

  type SubPageSetup = {
    subPage: MR_SubPage;
    ccVal: number;
  };

  type RebindSubpageOnActivate = {
    page: MR_Page;
    surfaceValue: MR_SurfaceValue;
    ccVal: number;
  };

  type IncDecCommandBindings = {
    zoom: Common.IncDecCommandBinding;
    marker: Common.IncDecCommandBinding;
  };
}

declare namespace LaunchControlXl3 {
  type Config = Common.Config;

  type ControlSection = {
    shiftButton: MR_Button;
    encoderPageButtons: [pageUp: MR_Button, pageDown: MR_Button];
    trackButtons: [trackPrev: MR_Button, trackNext: MR_Button];
    transportButtons: [record: MR_Button, play: MR_Button];
    modeButton: MR_Button;
  };

  type EncoderSection = {
    encoders: MR_Knob[];
    labelFieldEncoders: MR_SurfaceLabelField;
  };

  type FaderButtonSection = {
    buttons: MR_Button[];
    soloArm: MR_Button;
    muteSelect: MR_Button;
  };

  type FaderSection = {
    faders: MR_Fader[];
    labelFieldFaders: MR_SurfaceLabelField;
  };

  type TransportSection = {
    zoom: Common.IncDecEncoder;
    marker: Common.IncDecEncoder;
    loop: MR_SurfaceCustomValueVariable;
  };

  type UserInterface = {
    controlSection: ControlSection;
    encoderSection: EncoderSection;
    faderButtonSection: FaderButtonSection;
    faderSection: FaderSection;
    transportSection: TransportSection;
  };

  type SubPages = Common.SubPages & {
    Shift?: ShiftSubPage;
    ['DAW Mode']?: {
      ['DAW Control']: MR_SubPage;
      ['DAW Mixer']: MR_SubPage;
    };
    ['Fader Buttons Solo / Arm']?: {
      Solo: MR_SubPage;
      Arm: MR_SubPage;
    };
    ['Fader Buttons Mute / Select']?: {
      Mute: MR_SubPage;
      Select: MR_SubPage;
    };
    Sends?: MR_SubPage[];
  };
}
