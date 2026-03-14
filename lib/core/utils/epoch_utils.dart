/// Returns the current UTC time as milliseconds since epoch.
///
/// All database timestamp columns store this format. Use this function
/// instead of calling `DateTime.now().millisecondsSinceEpoch` directly
/// to keep the convention in one place.
int epochNowMs() => DateTime.now().millisecondsSinceEpoch;
