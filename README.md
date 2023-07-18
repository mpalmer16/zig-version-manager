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
