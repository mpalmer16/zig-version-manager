# Zig Version Manager

The purpose of this application is to download and install the current nightly Zig release.  While this work is much better
suited to a single shell script, the intention here is to learn about Zig while building something useful.  This is not recommended for use by anyone, and is only intended as an interesting exercise in writing a non-trivial Zig program.

That being said, it has been a lot of fun to work on!  Zig is an interesting language in its approach to low level programming that keeps things sane and simple.  It does not hide the difficult parts from the programmer, but instead encourages good practices and clean code.  While the [language reference](https://ziglang.org/documentation/master/) is very good, some of the most useful insights come directly from the [standard library](https://github.com/ziglang/zig/tree/master/lib/std) itself - because after all it's all just written in Zig.

Other great learning resources:
* [ziglearn.org](https://ziglearn.org/)
* [ziggit.dev](https://ziggit.dev/)

This application currently only runs on linux. I'm running this on a linux system (arch) running 
inside of windows (wsl2) with the following:
* a `.bashrc` line that sources the local `~/.zig/.zigrc` to get the current zig version tag
* another `.bashrc` line that adds this exported varable (`ZIG_NIGHTLY_PATH`) to the `PATH`

I would like to see it run on other platforms, but that is not a priority right now.

The whole point of this is to do the work of fetching and setting up a nightly build quickly and easily.  When working with Zig it
is important to keep up to date with changes as they come in.  Other languages with a stable 1.0 release encourage users to
stay away from the nightly branch, but with Zig, given the active and breaking changes that are always happening leading up to
a release (0.11 at this time), working with a nightly build is often a better idea than staying on the last release (currently 0.10.1).
How does a project like [TigerBeetle](https://tigerbeetle.com/) exist in a world like this, you ask?  I'm not sure, but it seems to
be working for them!

Some things that might be added:
* more supported platforms
* configs in a file that is read at runtime
* more tests (because zig tests are easy and awesome)
* arguments to pass that allow for different versions to be pulled


Note:
* `zig build -p <some path>` allows for the generated build artifact to be placed somewhere other than `./zig-out/bin`
* given this is installing zig to `~/.zig`, one idea is to add a bin folder there for the executable, and to add that to the `PATH`
* in my `.bashrc` file I added `export PATH=~/.zig/bin:$PATH` to append the location
* then using `zig build -p ~/.zig` (note the lack of `bin`) I can have the executable installed there
* now I can run this program directly with just the name
