# Zig Version Manager

To make this work right now you will need a few things setup ahead of time.

I'm running this on a linux system (arch) running inside of windows (wsl2) with the following:
* a `.bashrc` line that sources the local `~/.zig/.zigrc` to get the current zig version tag
* another `.bashrc` line that adds this exported varable (`ZIG_NIGHTLY_PATH`) to the `PATH`

The whole point of this is to do the work of fetching and setting up a nightly build quickly and easily, but there
is of course room for improvement.

Some things that will be added:
* configs in a file that is read at runtime
* more tests (because zig tests are easy and awesome)
* arguments to pass that allow for different versions to be pulled


Note:
* `zig build -p <some path>` allows for the generated build artifact to be placed somewhere other than `./zig-out/bin`
* given this is installing zig to `~/.zig`, one idea is to add a bin folder there for the executable, and to add that to the `PATH`
* in my `.bashrc` file I added `export PATH=~/.zig/bin:$PATH` to append the location
* then using `zig build -p ~/.zig` (note the lack of `bin`) I can have the executable installed there
* now I can run this program directly with just the name
