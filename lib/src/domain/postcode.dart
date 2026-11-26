/// Result of parsing what the user typed into the postcode field (PRD US-4).
sealed class PostcodeResult {
  const PostcodeResult();
}

/// A GB outward code, such as "RG10". Only this is ever sent or stored.
final class ValidOutcode extends PostcodeResult {
  const ValidOutcode(this.outcode);
  final String outcode;
}

/// Not a UK postcode format.
final class InvalidPostcode extends PostcodeResult {
  const InvalidPostcode();
}

/// A UK postcode outside the GB grid forecast, such as Northern Ireland.
final class NotCovered extends PostcodeResult {
  const NotCovered(this.place);
  final String place;
}

// Outward code, then an optional inward code ("9XY") with or without a space.
final _postcode = RegExp(r'^([A-Z]{1,2}[0-9][A-Z0-9]?)(?: ?[0-9][A-Z]{2})?$');

const _notCovered = {
  'BT': 'Northern Ireland',
  'GY': 'Guernsey',
  'JE': 'Jersey',
  'IM': 'Isle of Man',
};

/// Accepts full or outward-only postcodes in any case and spacing.
PostcodeResult parsePostcode(String input) {
  final normalised = input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  final match = _postcode.firstMatch(normalised);
  if (match == null) return const InvalidPostcode();
  final outcode = match.group(1)!;
  final area = RegExp('^[A-Z]+').stringMatch(outcode)!;
  final place = _notCovered[area];
  return place == null ? ValidOutcode(outcode) : NotCovered(place);
}
