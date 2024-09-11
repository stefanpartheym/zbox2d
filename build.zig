const std = @import("std");

pub fn build(b: *std.Build) void {
    const options = .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    };

    // Dependencies
    const box2d_dep = b.dependency("box2d", .{});

    // Provide the (native) library as zig module.
    const mod = b.addModule("zbox2d-native", .{
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
            .flags = &.{},
        });
    }

    // Provide an executable to run a basic box2d example.
    const exe = b.addExecutable(.{
        .name = "zbox2d-example",
        .root_source_file = b.path("src/main.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });

    exe.root_module.addImport("zbox2d-native", mod);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Library unit tests.
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
