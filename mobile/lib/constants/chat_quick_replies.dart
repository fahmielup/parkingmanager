/// Hardcoded quick reply chips available only to the DRIVER role.
/// Prevents soft-keyboard typing while driving.
class ChatQuickReplies {
  const ChatQuickReplies._();

  static const List<String> driverReplies = [
    'Heading to Zone A',
    'Heading to Zone B',
    'Shuttle Full - Moving to CIQ',
    'Arrived at CIQ Drop-off',
  ];
}
