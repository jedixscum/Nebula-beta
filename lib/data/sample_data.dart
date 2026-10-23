import '../domain/media_item.dart';

const _base = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/';

/// Demo catalog using public sample videos (needs internet to play).
const sampleItems = <MediaItem>[
  MediaItem(id: 'bbb', introEndSec: 20, title: 'Big Buck Bunny', year: 2008, type: MediaType.movie,
    synopsis: 'A giant rabbit takes revenge on three bullying rodents.',
    director: 'Sacha Goedegebure', runtimeMin: 10, rating: 7.6,
    cast: ['Animated short'], genres: ['Animation', 'Comedy'], streamUrl: 'https://uploads.video-commander.com/sample/BigBuckBunny.mp4'),
  MediaItem(id: 'ed', introEndSec: 20, title: 'Elephants Dream', year: 2006, type: MediaType.movie,
    synopsis: 'Two strangers explore a surreal mechanical world.',
    director: 'Bassam Kurdali', runtimeMin: 11, rating: 6.4,
    cast: ['Proog', 'Emo'], genres: ['Sci-Fi', 'Animation'], streamUrl: '${_base}ElephantsDream.mp4'),
  MediaItem(id: 'sintel', introEndSec: 20, title: 'Sintel', year: 2010, type: MediaType.movie,
    synopsis: 'A young woman searches for her lost dragon.',
    director: 'Colin Levy', runtimeMin: 15, rating: 7.4,
    cast: ['Halina Reijn'], genres: ['Fantasy', 'Animation'], streamUrl: '${_base}Sintel.mp4'),
  MediaItem(id: 'tos', introEndSec: 20, title: 'Tears of Steel', year: 2012, type: MediaType.movie,
    synopsis: 'Warriors and scientists try to save the world from robots.',
    director: 'Ian Hubert', runtimeMin: 12, rating: 6.5,
    cast: ['Derek de Lint'], genres: ['Sci-Fi'], streamUrl: '${_base}TearsOfSteel.mp4'),
  MediaItem(id: 'fire', title: 'For Bigger Blazes', year: 2013, type: MediaType.show,
    synopsis: 'Demo episode: a short blaze reel.',
    director: 'Google', runtimeMin: 1, rating: 5.0,
    cast: [], genres: ['Demo'], streamUrl: '${_base}ForBiggerBlazes.mp4'),
  MediaItem(id: 'joy', title: 'For Bigger Joyrides', year: 2013, type: MediaType.show,
    synopsis: 'Demo episode: a joyride reel.',
    director: 'Google', runtimeMin: 1, rating: 5.0,
    cast: [], genres: ['Demo'], streamUrl: '${_base}ForBiggerJoyrides.mp4'),
];

MediaItem? findItem(String id) {
  for (final m in sampleItems) { if (m.id == id) return m; }
  return null;
}
