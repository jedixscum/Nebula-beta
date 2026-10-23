enum MediaType { movie, show, live }

/// External subtitle offered by an addon.
class ExtSub {
  final String url, lang;
  const ExtSub(this.url, this.lang);
}

class MediaItem {
  final String id, title, synopsis, director;
  final int year, runtimeMin;
  final double rating;
  final MediaType type;
  final List<String> cast, genres;
  final String? streamUrl, posterUrl;
  final int? introEndSec; // demo skip-intro metadata
  final Map<String, String>? headers; // HTTP headers required by the stream
  final List<ExtSub> extSubs;
  const MediaItem({
    required this.id, required this.title, required this.year, required this.type,
    required this.synopsis, required this.director, required this.runtimeMin,
    required this.rating, required this.cast, required this.genres,
    this.streamUrl, this.posterUrl, this.introEndSec, this.headers, this.extSubs = const [],
  });

  /// Addon protocol type name.
  String get typeStr => type == MediaType.show ? 'series' : type == MediaType.live ? 'tv' : 'movie';

  MediaItem copyWith({String? id, String? title, String? streamUrl,
          Map<String, String>? headers, List<ExtSub>? extSubs}) =>
      MediaItem(
        id: id ?? this.id, title: title ?? this.title, year: year, type: type, synopsis: synopsis,
        director: director, runtimeMin: runtimeMin, rating: rating, cast: cast, genres: genres,
        streamUrl: streamUrl ?? this.streamUrl, posterUrl: posterUrl, introEndSec: introEndSec,
        headers: headers ?? this.headers, extSubs: extSubs ?? this.extSubs);

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'year': year, 'type': type.index, 'synopsis': synopsis,
        'director': director, 'runtime': runtimeMin, 'rating': rating, 'cast': cast,
        'genres': genres, 'poster': posterUrl,
      };

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        id: j['id'] as String, title: j['title'] as String, year: j['year'] as int,
        type: MediaType.values[j['type'] as int], synopsis: j['synopsis'] as String,
        director: j['director'] as String, runtimeMin: j['runtime'] as int,
        rating: (j['rating'] as num).toDouble(), cast: List<String>.from(j['cast'] as List),
        genres: List<String>.from(j['genres'] as List), posterUrl: j['poster'] as String?);
}
