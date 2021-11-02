import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:ilhewl/APIs/api.dart';
import 'package:ilhewl/Helpers/mediaitem_converter.dart';
import 'package:hive/hive.dart';
import 'package:ilhewl/Screens/Player/audioplayer.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audio_session/audio_session.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

class AudioPlayerHandlerImpl extends BaseAudioHandler with QueueHandler, SeekHandler implements AudioPlayerHandler {
  int count;
  Timer _sleepTimer;
  bool recommend = true;
  bool loadStart = true;
  bool useDown = true;
  AndroidEqualizerParameters _equalizerParams;

  final _equalizer = AndroidEqualizer();
  AudioPlayer _player;
  String preferredQuality;
  final converter = MediaItemConverter();

  int index;
  Box downloadsBox = Hive.box('downloads');

  final BehaviorSubject<List<MediaItem>> _recentSubject = BehaviorSubject.seeded(<MediaItem>[]);
  final _playlist = ConcatenatingAudioSource(children: []);
  @override
  final BehaviorSubject<double> volume = BehaviorSubject.seeded(1.0);
  @override
  final BehaviorSubject<double> speed = BehaviorSubject.seeded(1.0);
  final _mediaItemExpando = Expando<MediaItem>();

  Stream<List<IndexedAudioSource>> get _effectiveSequence => Rx.combineLatest3<List<IndexedAudioSource>, List<int>, bool, List<IndexedAudioSource>>(_player.sequenceStream,
      _player.shuffleIndicesStream, _player.shuffleModeEnabledStream,
          (sequence, shuffleIndices, shuffleModeEnabled) {
        if (sequence == null) return [];
        if (!shuffleModeEnabled) return sequence;
        if (shuffleIndices == null) return null;
        if (shuffleIndices.length != sequence.length) return null;
        return shuffleIndices.map((i) => sequence[i]).toList();
      }).whereType<List<IndexedAudioSource>>();

  int getQueueIndex(int currentIndex, List<int> shuffleIndices,
      {bool shuffleModeEnabled = false}) {
    final effectiveIndices = _player.effectiveIndices ?? [];
    final shuffleIndicesInv = List.filled(effectiveIndices.length, 0);
    for (var i = 0; i < effectiveIndices.length; i++) {
      shuffleIndicesInv[effectiveIndices[i]] = i;
    }
    return (shuffleModeEnabled &&
        ((currentIndex ?? 0) < shuffleIndicesInv.length))
        ? shuffleIndicesInv[currentIndex ?? 0]
        : currentIndex;
  }

  @override
  Stream<QueueState> get queueState =>
      Rx.combineLatest3<List<MediaItem>, PlaybackState, List<int>, QueueState>(
          queue,
          playbackState,
          _player.shuffleIndicesStream.whereType<List<int>>(),
              (queue, playbackState, shuffleIndices) => QueueState(
            queue,
            playbackState.queueIndex,
            playbackState.shuffleMode == AudioServiceShuffleMode.all
                ? shuffleIndices
                : null,
            playbackState.repeatMode,
          )).where((state) =>
      state.shuffleIndices == null ||
          state.queue.length == state.shuffleIndices.length);

  AudioPlayerHandlerImpl() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    await startService();

    speed.debounceTime(const Duration(milliseconds: 250)).listen((speed) {
      playbackState.add(playbackState.value.copyWith(speed: speed));
    });

    preferredQuality = Hive.box('settings').get('streamingQuality', defaultValue: '96 kbps').toString();
    recommend = Hive.box('settings').get('autoplay', defaultValue: true) as bool;
    loadStart = Hive.box('settings').get('loadStart', defaultValue: true) as bool;
    if (loadStart) {
      final List recentList = await Hive.box('cache').get('recentSongs', defaultValue: [])?.toList() as List;
      final List<MediaItem> lastQueue = recentList.map((e) => converter.mapToMediaItem(e as Map)).toList();
      await updateQueue(lastQueue);
    }

    mediaItem.whereType<MediaItem>().listen((item) {
      if (count != null) {
        count = count - 1;
        if (count <= 0) {
          count = null;
          stop();
        }
      }
    });

    Rx.combineLatest4<int, List<MediaItem>, bool, List<int>, MediaItem>(
        _player.currentIndexStream,
        queue,
        _player.shuffleModeEnabledStream,
        _player.shuffleIndicesStream,
            (index, queue, shuffleModeEnabled, shuffleIndices) {
          final queueIndex = getQueueIndex(index, shuffleIndices, shuffleModeEnabled: shuffleModeEnabled);
          return (queueIndex != null && queueIndex < queue.length)
              ? queue[queueIndex]
              : null;
        }).whereType<MediaItem>().distinct().listen(mediaItem.add);

    // Propagate all events from the audio player to AudioService clients.
    _player.playbackEventStream.listen(_broadcastState);

    _player.shuffleModeEnabledStream.listen((enabled) => _broadcastState(_player.playbackEvent));

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        stop();
        _player.seek(Duration.zero, index: 0);
      }
    });
    // Broadcast the current queue.
    _effectiveSequence.map((sequence) =>
        sequence.map((source) => _mediaItemExpando[source]).toList())
        .pipe(queue);

    _playlist.addAll(queue.value.map(_itemToSource).toList());
    await _player.setAudioSource(_playlist);
  }

  AudioSource _itemToSource(MediaItem mediaItem) {
    final audioSource = AudioSource.uri(
        mediaItem.artUri.toString().startsWith('file:')
            ? Uri.file(mediaItem.extras['url'].toString())
            : (downloadsBox.containsKey(mediaItem.id) && useDown)
            ? Uri.file(
            (downloadsBox.get(mediaItem.id) as Map)['path'].toString())
            : Uri.parse(mediaItem.extras['url'].toString().replaceAll(
            '_96.', "_${preferredQuality.replaceAll(' kbps', '')}.")));

    _mediaItemExpando[audioSource] = mediaItem;
    return audioSource;
  }

  List<AudioSource> _itemsToSources(List<MediaItem> mediaItems) {
    preferredQuality = Hive.box('settings').get('streamingQuality', defaultValue: '96 kbps').toString();
    useDown = Hive.box('settings').get('useDown', defaultValue: true) as bool;
    return mediaItems.map(_itemToSource).toList();
  }

  @override
  Future<void> onTaskRemoved() async {
    final bool stopForegroundService = Hive.box('settings').get('stopForegroundService', defaultValue: true) as bool;
    if (stopForegroundService) {
      await stop();
    }
  }

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic> options]) async {
    switch (parentMediaId) {
      case AudioService.recentRootId:
        return _recentSubject.value;
      default:
        return queue.value;
    }
  }

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
    switch (parentMediaId) {
      case AudioService.recentRootId:
        final stream = _recentSubject.map((_) => <String, dynamic>{});
        return _recentSubject.hasValue
            ? stream.shareValueSeeded(<String, dynamic>{})
            : stream.shareValue();
      default:
        return Stream.value(queue.value)
            .map((_) => <String, dynamic>{})
            .shareValue();
    }
  }

  Future<void> startService() async {
    final bool withPipeline = Hive.box('settings').get('supportEq', defaultValue: true) as bool;
    if (withPipeline) {
      final AudioPipeline _pipeline = AudioPipeline(
        androidAudioEffects: [
          _equalizer,
        ],
      );
      _player = AudioPlayer(audioPipeline: _pipeline);
    } else {
      _player = AudioPlayer();
    }
  }

  Future<void> addRecentlyPlayed(MediaItem mediaitem) async {
    List recentList = await Hive.box('cache').get('recentSongs', defaultValue: [])?.toList() as List;

    final Map item = converter.mediaItemtoMap(mediaitem);
    recentList.insert(0, item);

    final jsonList = recentList.map((item) => jsonEncode(item)).toList();
    final uniqueJsonList = jsonList.toSet().toList();
    recentList = uniqueJsonList.map((item) => jsonDecode(item)).toList();

    if (recentList.length > 30) {
      recentList = recentList.sublist(0, 30);
    }
    Hive.box('cache').put('recentSongs', recentList);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    await _playlist.add(_itemToSource(mediaItem));
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    await _playlist.addAll(_itemsToSources(mediaItems));
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    await _playlist.insert(index, _itemToSource(mediaItem));
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    await _playlist.clear();
    await _playlist.addAll(_itemsToSources(newQueue));
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    final index = queue.value.indexWhere((item) => item.id == mediaItem.id);
    _mediaItemExpando[_player.sequence[index]] = mediaItem;
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final index = queue.value.indexOf(mediaItem);
    await _playlist.removeAt(index);
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    await _playlist.removeAt(index);
  }

  @override
  Future<void> moveQueueItem(int currentIndex, int newIndex) async {
    await _playlist.move(currentIndex, newIndex);
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.children.length) return;

    _player.seek(Duration.zero,
        index: _player.shuffleModeEnabled
            ? _player.shuffleIndices[index]
            : index);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await playbackState.firstWhere((state) => state.processingState == AudioProcessingState.idle);
  }

  @override
  Future customAction(String name, [Map<String, dynamic> extras]) {
    if (name == 'sleepTimer') {
      _sleepTimer.cancel();
      if (extras['time'] != null &&
          extras['time'].runtimeType == int &&
          extras['time'] > 0 as bool) {
        _sleepTimer = Timer(Duration(minutes: extras['time'] as int), () {
          stop();
        });
      }
    }
    if (name == 'sleepCounter') {
      if (extras['count'] != null &&
          extras['count'].runtimeType == int &&
          extras['count'] > 0 as bool) {
        count = extras['count'] as int;
      }
    }

    if (name == 'setBandGain') {
      final bandIdx = extras['band'] as int;
      final gain = extras['gain'] as double;
      _equalizerParams.bands[bandIdx].setGain(gain);
    }

    if (name == 'setEqualizer') {
      _equalizer.setEnabled(extras['value'] as bool);
    }

    if (name == 'getEqualizerParams') {
      return getEqParms();
    }
    return super.customAction(name, extras);
  }

  Future<Map> getEqParms() async {
    _equalizerParams ??= await _equalizer.parameters;
    final List<AndroidEqualizerBand> bands = _equalizerParams.bands;
    final List<Map> bandList = bands
        .map((e) => {
      'centerFrequency': e.centerFrequency,
      'gain': e.gain,
      'index': e.index
    })
        .toList();

    return {
      'maxDecibels': _equalizerParams.maxDecibels,
      'minDecibels': _equalizerParams.minDecibels,
      'bands': bandList
    };
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    final enabled = mode == AudioServiceShuffleMode.all;
    if (enabled) {
      await _player.shuffle();
    }
    playbackState.add(playbackState.value.copyWith(shuffleMode: mode));
    await _player.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
    await _player.setLoopMode(LoopMode.values[repeatMode.index]);
  }

  @override
  Future<void> setSpeed(double speed) async {
    this.speed.add(speed);
    await _player.setSpeed(speed);
  }

  @override
  Future<void> setVolume(double volume) async {
    this.volume.add(volume);
    await _player.setVolume(volume);
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:
        _handleMediaActionPressed();
        break;
      case MediaButton.next:
        await skipToNext();
        break;
      case MediaButton.previous:
        await skipToPrevious();
        break;
    }
  }

  BehaviorSubject<int> _tappedMediaActionNumber;
  Timer _timer;

  void _handleMediaActionPressed() {
    if (_timer == null) {
      _tappedMediaActionNumber = BehaviorSubject.seeded(1);
      _timer = Timer(const Duration(milliseconds: 800), () {
        final tappedNumber = _tappedMediaActionNumber.value;
        if (tappedNumber == 1) {
          if (playbackState.value.playing) {
            pause();
          } else {
            play();
          }
        } else if (tappedNumber == 2) {
          skipToNext();
        } else {
          skipToPrevious();
        }

        _tappedMediaActionNumber.close();
        _timer.cancel();
        _timer = null;
      });
    } else {
      final current = _tappedMediaActionNumber.value;
      _tappedMediaActionNumber.add(current + 1);
    }
  }

  /// Broadcasts the current state to all clients.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final queueIndex = getQueueIndex(
        event.currentIndex, _player.shuffleIndices,
        shuffleModeEnabled: _player.shuffleModeEnabled);
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState],
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: queueIndex,
    ));
  }


  //
  // setAudioPlayer() {
  //   _player = AudioPlayer(
  //     handleInterruptions: true,
  //     androidApplyAudioAttributes: true,
  //     handleAudioSessionActivation: true,
  //     audioPipeline: AudioPipeline(
  //       androidAudioEffects: [
  //         _equalizer,
  //       ],
  //     ),
  //   );
  // }
  //
  // Timer _sleepTimer;
  // StreamSubscription<PlaybackEvent> _eventSubscription;
  // List<MediaItem> queue = [];
  // bool shuffle = false;
  // List<MediaItem> defaultQueue = [];
  // ConcatenatingAudioSource concatenatingAudioSource;
  //
  // int index;
  // bool offline;
  // MediaItem get mediaItem => index == null ? queue[0] : queue[index];
  //
  // Future<void> onTaskRemoved() async {
  //   bool stopForegroundService =
  //       Hive.box('settings').get('stopForegroundService') ?? true;
  //   if (stopForegroundService) {
  //     await onStop();
  //   }
  // }
  //
  // initiateBox() async {
  //   try {
  //     await Hive.initFlutter();
  //   } catch (e) {}
  //   try {
  //     await Hive.openBox('settings');
  //   } catch (e) {
  //     print('Failed to open Settings Box');
  //     print("Error: $e");
  //     Directory dir = await getApplicationDocumentsDirectory();
  //     String dirPath = dir.path;
  //     String boxName = "settings";
  //     File dbFile = File('$dirPath/$boxName.hive');
  //     File lockFile = File('$dirPath/$boxName.lock');
  //     await dbFile.delete();
  //     await lockFile.delete();
  //     await Hive.openBox("settings");
  //   }
  //   try {
  //     await Hive.openBox('recentlyPlayed');
  //   } catch (e) {
  //     print('Failed to open Recent Box');
  //     print("Error: $e");
  //     Directory dir = await getApplicationDocumentsDirectory();
  //     String dirPath = dir.path;
  //     String boxName = "recentlyPlayed";
  //     File dbFile = File('$dirPath/$boxName.hive');
  //     File lockFile = File('$dirPath/$boxName.lock');
  //     await dbFile.delete();
  //     await lockFile.delete();
  //     await Hive.openBox("recentlyPlayed");
  //   }
  // }
  //
  // addRecentlyPlayed(MediaItem mediaitem) async {
  //   if (mediaItem.artUri.toString().startsWith('https://img.youtube.com'))
  //     return;
  //   List recentList;
  //   try {
  //     recentList = await Hive.box('recentlyPlayed').get('recentSongs').toList();
  //   } catch (e) {
  //     recentList = null;
  //   }
  //
  //   Map item = MediaItemConverter().mediaItemtoMap(mediaItem);
  //   recentList == null ? recentList = [item] : recentList.insert(0, item);
  //
  //   final jsonList = recentList.map((item) => jsonEncode(item)).toList();
  //   final uniqueJsonList = jsonList.toSet().toList();
  //   recentList = uniqueJsonList.map((item) => jsonDecode(item)).toList();
  //
  //   if (recentList.length > 30) {
  //     recentList = recentList.sublist(0, 30);
  //   }
  //   Hive.box('recentlyPlayed').put('recentSongs', recentList);
  //   final userID = Hive.box('settings').get('userID');
  //   final dbRef = FirebaseDatabase.instance.reference().child("Users");
  //   dbRef.child(userID.toString()).update({"recentlyPlayed": recentList});
  // }
  //
  // @override
  // Future<void> onStart(Map<String, dynamic> params) async {
  //   index = params['index'];
  //   offline = params['offline'];
  //   preferredQuality = params['quality'];
  //   await initiateBox();
  //   await setAudioPlayer();
  //
  //   final session = await AudioSession.instance;
  //   await session.configure(AudioSessionConfiguration.music());
  //
  //   _player.currentIndexStream.distinct().listen((idx) {
  //     if (idx != null && queue.isNotEmpty) {
  //       index = idx;
  //       AudioServiceBackground.setMediaItem(queue[idx]);
  //     }
  //   });
  //
  //   // _player.sequenceStateStream.distinct().listen((state) {
  //   // if (state != null) {
  //   // MediaItem mediaItem = state.currentSource.tag;
  //   // AudioServiceBackground.setMediaItem(mediaItem);
  //   // index = queue.indexWhere((element) => element == mediaItem);
  //   // }
  //   // });
  //
  //   _eventSubscription = _player.playbackEventStream.listen((event) {
  //     _broadcastState();
  //   });
  //
  //   _player.processingStateStream.listen((state) {
  //     if (state == ProcessingState.completed) {
  //       AudioService.stop();
  //     }
  //   });
  // }
  //
  // @override
  // Future<void> onSkipToQueueItem(String mediaId) async {
  //   final newIndex = queue.indexWhere((item) => item.id == mediaId);
  //   index = newIndex;
  //   if (newIndex == -1) return;
  //   _player.seek(Duration.zero, index: newIndex);
  //   Api().playTrack(mediaId, "song");
  //   if (!offline) addRecentlyPlayed(queue[newIndex]);
  // }
  //
  // @override
  // Future<void> onUpdateQueue(List<MediaItem> _queue) async {
  //   await AudioServiceBackground.setQueue(_queue);
  //   await AudioServiceBackground.setMediaItem(_queue[index]);
  //   concatenatingAudioSource = ConcatenatingAudioSource(
  //     children: _queue
  //         .map((item) => AudioSource.uri(
  //             offline
  //                 ? Uri.file(item.extras['url'])
  //                 : Uri.parse(item.extras['url'].replaceAll(
  //                     "_96.", "_${preferredQuality.replaceAll(' kbps', '')}.")),
  //             tag: item))
  //         .toList(),
  //   );
  //   await _player.setAudioSource(concatenatingAudioSource);
  //   await _player.seek(Duration.zero, index: index);
  //   queue = _queue;
  // }
  //
  // @override
  // Future<void> onAddQueueItemAt(MediaItem mediaItem, int addIndex) async {
  //   await concatenatingAudioSource.insert(
  //       addIndex,
  //       AudioSource.uri(
  //           offline
  //               ? Uri.file(mediaItem.extras['url'])
  //               : Uri.parse(mediaItem.extras['url'].replaceAll(
  //                   "_96.", "_${preferredQuality.replaceAll(' kbps', '')}.")),
  //           tag: mediaItem));
  //   queue.insert(addIndex, mediaItem);
  //   await AudioServiceBackground.setQueue(queue);
  // }
  //
  // @override
  // Future<void> onAddQueueItem(MediaItem mediaItem) async {
  //   await concatenatingAudioSource.add(AudioSource.uri(
  //       offline
  //           ? Uri.file(mediaItem.extras['url'])
  //           : Uri.parse(mediaItem.extras['url'].replaceAll(
  //               "_96.", "_${preferredQuality.replaceAll(' kbps', '')}.")),
  //       tag: mediaItem));
  //   if (mediaItem.extras["selling"] == 1 && !mediaItem.extras["purchased"]) {
  //   } else {
  //     queue.add(mediaItem);
  //     await AudioServiceBackground.setQueue(queue);
  //   }
  // }
  //
  // @override
  // Future<void> onRemoveQueueItem(MediaItem mediaItem) async {
  //   final removeIndex = queue.indexWhere((item) => item == mediaItem);
  //   queue.remove(mediaItem);
  //   await concatenatingAudioSource.removeAt(removeIndex);
  //   await AudioServiceBackground.setQueue(queue);
  // }
  //
  // Future<void> onReorderQueue(int oldIndex, int newIndex) async {
  //   concatenatingAudioSource.move(oldIndex, newIndex);
  //   MediaItem item = queue.removeAt(oldIndex);
  //   queue.insert(newIndex, item);
  //   await AudioServiceBackground.setQueue(queue);
  // }
  //
  // @override
  // Future<void> onPlay() async {
  //   if (!offline) addRecentlyPlayed(queue[index]);
  //   Api().playTrack(queue[index].id, "song");
  //   print("Play");
  //   _player.play();
  // }
  //
  // @override
  // Future<dynamic> onCustomAction(String myFunction, dynamic myVariable) {
  //   if (myFunction == 'sleepTimer') {
  //     _sleepTimer?.cancel();
  //     if (myVariable.runtimeType == int &&
  //         myVariable != null &&
  //         myVariable > 0) {
  //       _sleepTimer = Timer(Duration(minutes: myVariable), () {
  //         onStop();
  //       });
  //     }
  //   }
  //
  //   if (myFunction == 'reorder') {
  //     onReorderQueue(myVariable[0], myVariable[1]);
  //   }
  //
  //   if (myFunction == 'setEqualizer') {
  //     _equalizer.setEnabled((myVariable[0]));
  //   }
  //
  //   if (myFunction == 'setVolume') {
  //     double vl = myVariable;
  //     _player.setVolume(vl);
  //   }
  //
  //   return Future.value(true);
  // }
  //
  // @override
  // Future<void> onSetRepeatMode(AudioServiceRepeatMode repeatMode) {
  //   switch (repeatMode) {
  //     case AudioServiceRepeatMode.all:
  //       _player.setLoopMode(LoopMode.all);
  //       break;
  //
  //     case AudioServiceRepeatMode.one:
  //       _player.setLoopMode(LoopMode.one);
  //       break;
  //     default:
  //       _player.setLoopMode(LoopMode.off);
  //       break;
  //   }
  //
  //   return super.onSetRepeatMode(repeatMode);
  // }
  //
  // @override
  // Future<void> onSetShuffleMode(AudioServiceShuffleMode shuffleMode) async {
  //   switch (shuffleMode) {
  //     case AudioServiceShuffleMode.none:
  //       queue = defaultQueue;
  //       _player.setShuffleModeEnabled(false);
  //       AudioServiceBackground.setQueue(queue);
  //       break;
  //     case AudioServiceShuffleMode.group:
  //       break;
  //     case AudioServiceShuffleMode.all:
  //       defaultQueue = queue;
  //       await _player.setShuffleModeEnabled(true);
  //       await _player.shuffle();
  //       _player.sequenceStateStream
  //           .map((state) => state?.effectiveSequence)
  //           .distinct()
  //           .map((sequence) =>
  //               sequence.map((source) => source.tag as MediaItem).toList())
  //           .listen(AudioServiceBackground.setQueue);
  //       break;
  //   }
  // }
  //
  // @override
  // Future<void> onClick(MediaButton button) {
  //   switch (button) {
  //     case MediaButton.next:
  //       onSkipToNext();
  //       break;
  //     case MediaButton.previous:
  //       onSkipToPrevious();
  //       break;
  //     case MediaButton.media:
  //       _handleMediaActionPressed();
  //       break;
  //   }
  //   return Future.value();
  // }
  //
  // BehaviorSubject<int> _tappedMediaActionNumber;
  // Timer _timer;
  //
  // void _handleMediaActionPressed() {
  //   if (_timer == null) {
  //     _tappedMediaActionNumber = BehaviorSubject.seeded(1);
  //     _timer = Timer(Duration(milliseconds: 600), () {
  //       final tappedNumber = _tappedMediaActionNumber.value;
  //       if (tappedNumber == 1) {
  //         if (AudioServiceBackground.state.playing)
  //           onPause();
  //         else
  //           onPlay();
  //       } else if (tappedNumber == 2) {
  //         onSkipToNext();
  //       } else {
  //         onSkipToPrevious();
  //       }
  //
  //       _tappedMediaActionNumber.close();
  //       _timer.cancel();
  //       _timer = null;
  //     });
  //   } else {
  //     final current = _tappedMediaActionNumber.value;
  //     _tappedMediaActionNumber.add(current + 1);
  //   }
  // }
  //
  // @override
  // Future<void> onPause() => _player.pause();
  //
  // @override
  // Future<void> onSeekTo(Duration position) => _player.seek(position);
  //
  // @override
  // Future<void> onStop() async {
  //   await _player.dispose();
  //   _eventSubscription.cancel();
  //   await _broadcastState();
  //   await super.onStop();
  // }
  //
  // /// Broadcasts the current state to all clients.
  // Future<void> _broadcastState() async {
  //   await AudioServiceBackground.setState(
  //     controls: [
  //       MediaControl.skipToPrevious,
  //       if (_player.playing) MediaControl.pause else MediaControl.play,
  //       MediaControl.skipToNext,
  //       MediaControl.stop,
  //     ],
  //     systemActions: [
  //       MediaAction.seekTo,
  //       MediaAction.seekForward,
  //       MediaAction.seekBackward,
  //     ],
  //     androidCompactActions: [0, 1, 2],
  //     processingState: _getProcessingState(),
  //     playing: _player.playing,
  //     position: _player.position,
  //     bufferedPosition: _player.bufferedPosition,
  //     speed: _player.speed,
  //   );
  // }
  //
  // /// Maps just_audio's processing state into into audio_service's playing state.
  // AudioProcessingState _getProcessingState() {
  //   switch (_player.processingState) {
  //     case ProcessingState.idle:
  //       return AudioProcessingState.stopped;
  //     case ProcessingState.loading:
  //       return AudioProcessingState.connecting;
  //     case ProcessingState.buffering:
  //       return AudioProcessingState.buffering;
  //     case ProcessingState.ready:
  //       return AudioProcessingState.ready;
  //     case ProcessingState.completed:
  //       return AudioProcessingState.completed;
  //     default:
  //       throw Exception("Invalid state: ${_player.processingState}");
  //   }
  // }
}
