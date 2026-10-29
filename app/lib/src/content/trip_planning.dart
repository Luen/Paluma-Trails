/// Offline pre-visit notes. Their check date never implies live conditions.
class TripPlanningContent {
  const TripPlanningContent({
    required this.checked,
    required this.intro,
    required this.sections,
  });

  final String checked;
  final String intro;
  final List<TripPlanningSection> sections;

  factory TripPlanningContent.fromJson(Map<String, Object?> json) =>
      TripPlanningContent(
        checked: json['checked']! as String,
        intro: json['intro']! as String,
        sections: (json['sections']! as List)
            .cast<Map<String, Object?>>()
            .map(TripPlanningSection.fromJson)
            .toList(growable: false),
      );
}

/// A short topic with its own attribution and explicit online references.
class TripPlanningSection {
  const TripPlanningSection({
    required this.title,
    required this.paragraphs,
    required this.sources,
  });

  final String title;
  final List<String> paragraphs;
  final List<TripPlanningSource> sources;

  factory TripPlanningSection.fromJson(Map<String, Object?> json) =>
      TripPlanningSection(
        title: json['title']! as String,
        paragraphs: (json['paragraphs']! as List).cast<String>(),
        sources: (json['sources']! as List)
            .cast<Map<String, Object?>>()
            .map(TripPlanningSource.fromJson)
            .toList(growable: false),
      );
}

/// A reference whose label remains readable without opening the website.
class TripPlanningSource {
  const TripPlanningSource({required this.label, required this.url});

  final String label;
  final String url;

  factory TripPlanningSource.fromJson(Map<String, Object?> json) =>
      TripPlanningSource(
        label: json['label']! as String,
        url: json['url']! as String,
      );
}
