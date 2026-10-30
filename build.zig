const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zengine = b.dependency("zengine", .{});
    const zmod = zengine.module("zengine");
    const z = @import("zengine");
    const options = z.getOptions(b);

    const install_assets = try z.addInstallAssets(b);

    const core = b.addModule("arch", .{
        .root_source_file = b.path("src/core.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "zengine", .module = zmod },
        },
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = core },
            .{ .name = "zengine", .module = zmod },
        },
        .pic = true,
    });

    const check = b.addExecutable(.{
        .name = "arch",
        .root_module = exe_mod,
    });

    const exe = b.addExecutable(.{
        .name = "arch",
        .root_module = exe_mod,
    });
    exe.each_lib_rpath = false;
    const install_exe = b.addInstallArtifact(exe, .{});
    install_exe.step.dependOn(&install_assets.step);
    b.getInstallStep().dependOn(&install_exe.step);

    _ = try z.addExternal(b, .{
        .b = zengine.builder,
        .options = options,
        .target = target,
        .optimize = optimize,
    });

    const install_libs = try z.addInstallLibs(b, .{
        .b = zengine.builder,
        .module = zmod,
        .options = options,
        .target = target,
        .optimize = optimize,
    });
    exe.step.dependOn(install_libs);
    exe.each_lib_rpath = false;

    {
        const install_shaders_dir = try z.addCompileShaders(b, .{
            .b = zengine.builder,
            .module = zmod,
            .options = options,
            .optimize = optimize,
        });
        install_exe.step.dependOn(&install_shaders_dir.step);
    }
    const install_shaders = blk: {
        const install_shaders_dir = try z.addCompileShaders(b, .{
            .b = zengine.builder,
            .src = b.path("shaders"),
            .module = zmod,
            .options = options,
            .optimize = optimize,
        });
        install_exe.step.dependOn(&install_shaders_dir.step);
        break :blk install_shaders_dir;
    };
    _ = install_shaders;

    const check_step = b.step("check", "Check the app");
    check_step.dependOn(&check.step);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(&install_exe.step);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const mod_tests = b.addTest(.{
        .root_module = core,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
