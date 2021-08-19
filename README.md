# Let's Make Tracks

Quick and opinionated conversion of YouTube playlists to MP3 tracks.

## Description

I used to work in a computer lab that was on an isolated network (i.e. no Internet).  The lab was also
in the basement of an old Air Force building that basically served as a Faraday cage, so cell phone/mobile
service was almost non-existent.  In other words, the only music I had for the day was the music that
I already had on my phone.

I work best with music, and I wanted a way to take some great YouTube playlists with me into the lab.
Enter "Let's Make Tracks".  It's a phrase my mom used to say meaning, "let's go/leave/get out of
here", where *tracks* referred to the figurative trail of footprints left behind after leaving the
place.  But, I like that *tracks* can also refer to a musical subdivision of an album or a playlist.
So, here, using "Let's make tracks" is saying something like "let us begin making musical subdivisions
from a provided, larger playlist".

## Disclaimer

I'm an avid music consumer, and I buy music from the artists whose playlists I frequent (usually
using [bandcamp](https://bandcamp.com)).  I also listen to their playlists on ad-supported YouTube
and soundcloud.  I say this to emphasize that I don't condone using this script to deprive anyone of
their due royalties.  Don't be "that guy".  Nobody likes that guy.

## Requirements

* [Bash](https://www.gnu.org/software/bash/),
* [youtube-dl](https://ytdl-org.github.io/youtube-dl/download.html),
* [ffmpeg](https://www.ffmpeg.org/download.html), and
* [jq](https://stedolan.github.io/jq/download/)

If you're on a Linux system, you probably have Bash.  You need to install youtube-dl, ffmpeg (with
`libmp3lame` support), and jq.  I'll defer to those software providers for various installation
methods.

## Usage

```bash
$ ./make_tracks <YouTube Playlist Link>
```

I haven't tested this for other playlist providers because I only needed YouTube.  It probably
works since that capability is outsourced to youtube-dl, but your mileage may vary.  If you want
to add more robustness for additional youtube-dl extractors, fork it and have fun.
