//! This file copied from [Box2D.zig repository](https://github.com/bluesillybeard/Box2D.zig/blob/master/src/box2dnative.zig).

// In C, you would only import the headers you need.
// This is a binding, so ALL of the headers are included
const c = @cImport({
    // Many of these are unnessesary. They are all here since it was easiest to just
    // add all of them without thinking about which ones are actually needed
    @cInclude("box2d/base.h");
    @cInclude("box2d/box2d.h");
    @cInclude("box2d/collision.h");
    @cInclude("box2d/id.h");
    @cInclude("box2d/math_functions.h");
    @cInclude("box2d/types.h");
});
pub usingnamespace c;
