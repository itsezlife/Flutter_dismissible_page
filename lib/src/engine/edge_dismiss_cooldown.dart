/// Quiet interval after user paging before pager-axis edge dismissal re-arms.
///
/// [window] is the cool-down duration. Arming is decided from explicit
/// timestamps so unit tests need no widget tree or fake timers.
extension type const EdgeDismissCooldown(Duration window) {
  /// Whether edge dismissal may begin at [now].
  ///
  /// A pager that has never been user-paged ([lastUserPagingActivity] is
  /// `null`) is armed immediately. Otherwise the quiet interval must have
  /// elapsed since that stamp.
  bool isArmed({
    required DateTime now,
    DateTime? lastUserPagingActivity,
  }) {
    return switch (lastUserPagingActivity) {
      null => true,
      final activity => !now.isBefore(activity.add(window)),
    };
  }
}
