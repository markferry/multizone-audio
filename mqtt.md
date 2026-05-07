---
MQTT notes
---

# Mopidy
## State
```
media/canard/mopidy/i/sta
```

## Control
```
media/canard/mopidy/c/plb pause
```

```
|       Kind       | Subtopic |                               Values                              |
|:----------------:|:--------:|:-----------------------------------------------------------------:|
| Playback control | `/plb`   | `play` / `stop` / `pause` / `resume` / `toggle` / `prev` / `next` |
| Volume control   | `/vol`   | `=<int>` or `-<int>` or `+<int>`                                  |
| Add to queue     | `/add`   | `<uri:str>`                                                       |
| Load playlist    | `/loa`   | `<uri:str>`                                                       |
| Clear queue      | `/clr`   | ` `                                                               |
| Search tracks    | `/src`   | `<str>`                                                           |
| Request info     | `/inf`   | `state` / `volume` / `queue`                                  |

```

# Librespot
## State
```
media/canard/spotify started
media/canard/spotify volume_set
media/canard/spotify playing
media/canard/spotify paused
```

## Control

# shairport-sync

## State

## Control
```
media/kitchen/airplay/remote pause
```

commands:

```
command, beginff, beginrew, mutetoggle, nextitem, previtem, pause,
playpause, play, stop, playresume, shuffle_songs, volumedown, volumeup
```

# Kodi

## State
```
media/study/kodi/status/notification/Player.OnPlay {"val": "{\"item\":{\"id\":14996,\"type\":\"episode\"},\"player\":{\"playerid\":1,\"speed\":1}}"}
media/study/kodi/status/notification/Player.OnStop {"val": "{\"end\":true,\"item\":{\"id\":14996,\"type\":\"episode\"}}"}

```

## Control
```
media/command/playbackstate "pause"
```

# Jellyfin

Use the [Webhook plugin](https://github.com/jellyfin/jellyfin-plugin-webhook).

## State

Rename devices in Jellyfin to match audio zones.

Add MQTT Destination and configure with:

- Template:
  ```json
  {
  "notification_type": "{{NotificationType}}",
  "item_type": "{{ItemType}}",
  "name": "{{{Name}}}",
  "playback_position": "{{PlaybackPosition}}",
  "run_time": "{{RunTime}}",
  "is_paused": {{#if IsPaused}}true{{else}}false{{/if}}
  }
  ```

- Topic: `media/{{DeviceName}}/jellyfin/playbackstate`


  ```jsonl
  media/test-zone/jellyfin/playbackstate {
    "notification_type": "PlaybackStart",
    "item_type": "Movie",
    "name": "(500) Days of Summer",
    "playback_position": "00:00:00",
    "run_time": "01:35:04",
    "is_paused": false
  }

  media/test-zone/jellyfin/playbackstate {
    "notification_type": "PlaybackProgress",
    "item_type": "Movie",
    "name": "(500) Days of Summer",
    "playback_position": "00:00:01",
    "run_time": "01:35:04",
    "is_paused": false
  }

  media/test-zone/jellyfin/playbackstate {
    "notification_type": "PlaybackProgress",
    "item_type": "Movie",
    "name": "(500) Days of Summer",
    "playback_position": "00:00:00",
    "run_time": "01:35:05",
    "is_paused": true
  }

  media/test-zone/jellyfin/playbackstate {
    "notification_type": "PlaybackStop",
    "item_type": "Movie",
    "name": "(500) Days of Summer",
    "playback_position": "00:00:00",
    "run_time": "01:35:05",
    "is_paused": false
  }
  ```
