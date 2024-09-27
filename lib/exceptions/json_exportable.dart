/// An interface for objects that can be converted to a JSON map.
abstract class JsonExportable {
  /// Converts the object to a JSON map.
  Map<String, dynamic> toJson();
}
