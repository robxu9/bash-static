# bash-static

Because we all need the most static bash we can get in this world.

## Getting

Download from the Releases section or run `./build.sh`.

Note that you really can't have truly static binaries on Darwin or
Windows machines, because there are no static libraries that can be used.
But this will ensure that Darwin or Windows bash binaries will not rely on
anything else but their libcs.

On Linux, we use musl instead of glibc to avoid `dlopen()`.

## Rationale

This started as an experiment in Jan 2015 when Glider Labs was testing the
viability of potentially using just a statically linked bash entrypoint
as the only entrance into a container. So the following works:

```sh
FROM scratch
ADD bash
ENTRYPOINT ['/bash']
```

Adding in busybox would make the container relatively feature-complete
for debugging or just for common tools. This works great with a
container image that has busybox (i.e `progrium/busybox`).

If you're not going for purely static minimalism, you can achieve a similar
result just by using Alpine today, also discovered during this experiment in 2015.

## License

MIT
