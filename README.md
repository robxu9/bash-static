# bash-static

Because we all need the most static bash we can get in this world.

## Getting
Download from the Releases section or run `./build.sh`.

Note that you really can't have truly static binaries on Darwin or
Windows machines, because there are no static libraries that can be used.

On Linux, we use musl instead of glibc to avoid `dlopen()`.

## What's the point of this?
I can run bash anywhere! Even an empty Docker container.

```
FROM scratch
ADD bash
ENTRYPOINT ['/bash']
```

And it'll just work&trade;. Well, you'll be missing all the coreutils, so
it'll be close to useless, but hey! It works! You could probably add busybox
in now.

## Sponsored by...
> Really?

But actually. [Glider Labs](http://gliderlabs.com/). Cool people.
