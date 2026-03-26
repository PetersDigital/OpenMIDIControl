class MidiEvent {
  final int messageType; // e.g., 0xB0 for CC
  final int channel; // 0-15
  final int data1; // e.g., CC number
  final int data2; // e.g., CC value
  final int timestamp; // nanoseconds or milliseconds
  final String sourceId; // e.g., device id or port name

  const MidiEvent({
    required this.messageType,
    required this.channel,
    required this.data1,
    required this.data2,
    required this.timestamp,
    required this.sourceId,
  });

  factory MidiEvent.fromMap(Map<dynamic, dynamic> map) {
    // For now, the Android backend might send 'type' == 'cc' and 'cc', 'value' fields.
    // We'll normalize this into our UMP-ready structure.
    int messageType = 0;
    int channel = 0;
    int data1 = 0;
    int data2 = 0;

    if (map['type'] == 'cc') {
      messageType = 0xB0; // Control Change
      // Android currently doesn't send channel explicitly, defaulting to 0 for now
      channel = map['channel'] as int? ?? 0;
      data1 = map['cc'] as int? ?? 0;
      data2 = map['value'] as int? ?? 0;
    } else {
      // Fallback for other potential types if they are sent in the future
      messageType = map['messageType'] as int? ?? 0;
      channel = map['channel'] as int? ?? 0;
      data1 = map['data1'] as int? ?? 0;
      data2 = map['data2'] as int? ?? 0;
    }

    return MidiEvent(
      messageType: messageType,
      channel: channel,
      data1: data1,
      data2: data2,
      timestamp: map['timestamp'] as int? ?? 0,
      sourceId: map['sourceId'] as String? ?? 'unknown',
    );
  }

  @override
  String toString() {
    return 'MidiEvent(type: 0x${messageType.toRadixString(16)}, ch: $channel, d1: $data1, d2: $data2, src: $sourceId)';
  }
}
