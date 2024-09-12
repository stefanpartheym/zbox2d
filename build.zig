const std = @import("std");

pub fn build(b: *std.Build) void {
    const options = .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    };

    //
    // Module
    //

    // Dependencies
    const box2d_dep = b.dependency("box2d", .{});

    // Provide the (native) library as zig module.
    const mod = b.addModule("zbox2d", .{
        .root_source_file = b.path("src/root.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .link_libc = true,
    });

    for (box2d_include_paths) |include_path| {
        mod.addIncludePath(box2d_dep.path(include_path));
    }

    for (box2d_source_files) |file| {
        mod.addCSourceFile(.{
            .file = box2d_dep.path(b.pathJoin(&.{ "src", file })),
        });
    }

    //
    // Example
    //

    // Dependencies
    const raylib_dep = b.dependency("raylib-zig", .{});

    // Provide an executable to run a basic box2d example.
    const exe = b.addExecutable(.{
        .name = "zbox2d-example",
        .root_source_file = b.path("src/main.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });

    // Add box2d include paths to a compile step.
    // NOTE:
    // This might be necessary in order to make ZLS happy and provide LSP support
    // for native box2d symbols.
    // Otherwise, ZLS will complain about missing headers included in this modules
    // `root.zig`.
    // This is why this function is public and can be used in a consuming zig
    // project as follows:
    //
    // ```zig
    // const zbox2d_dep = b.dependency("zbox2d", options);
    // //...
    // for (zbox2d_dep.module("zbox2d").include_dirs.items) |include_dir| {
    //     exe.addIncludePath(include_dir.path.dupe(b));
    // }
    // ```
    for (box2d_include_paths) |include_path| {
        exe.addIncludePath(box2d_dep.path(include_path));
    }

    exe.linkLibrary(raylib_dep.artifact("raylib"));
    exe.root_module.addImport("zbox2d", mod);
    exe.root_module.addImport("raylib", raylib_dep.module("raylib"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    //
    // Unit tests
    //

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Module unit tests.
    const mod_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });

    const run_mod_unit_tests = b.addRunArtifact(mod_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_mod_unit_tests.step);
}

const box2d_include_paths = &[_][]const u8{
    "src",
    "include",
    "extern/glad",
    "extern/jsmn",
    "extern/simde",
};
const box2d_source_files = &[_][]const u8{
    "aabb.c",
    "allocate.c",
    "array.c",
    "bitset.c",
    "block_array.c",
    "body.c",
    "broad_phase.c",
    "constraint_graph.c",
    "contact.c",
    "contact_solver.c",
    "core.c",
    "distance.c",
    "distance_joint.c",
    "dynamic_tree.c",
    "geometry.c",
    "hull.c",
    "id_pool.c",
    "island.c",
    "joint.c",
    "manifold.c",
    "math_functions.c",
    "motor_joint.c",
    "mouse_joint.c",
    "prismatic_joint.c",
    "revolute_joint.c",
    "shape.c",
    "solver.c",
    "solver_set.c",
    "stack_allocator.c",
    "table.c",
    "timer.c",
    "types.c",
    "weld_joint.c",
    "wheel_joint.c",
    "world.c",
};
