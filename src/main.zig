const std = @import("std");
const json = std.json;
const zfetch = @import("zfetch");
const utils = @import("utils.zig");
const TtyColor = utils.TtyColor;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const stdout = std.io.getStdOut().writer();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try zfetch.init();
    defer zfetch.deinit();

    const url = try std.fmt.allocPrint(allocator, "https://api.github.com/repos/{s}", .{args[1]});
    defer allocator.free(url);

    const source = try utils.requestGet(allocator, url);
    defer allocator.free(source);

    const Query = struct {
        full_name: []const u8,
        private: bool,
        fork: bool,
        archived: bool,
        is_template: bool,
        description: []const u8,
        html_url: []const u8,
        language: []const u8,
        size: u32,
        stargazers_count: u32,
        watchers_count: u32,
        forks_count: u32,
        license: struct { name: []const u8 },
        created_at: []const u8,
        updated_at: []const u8,
        pushed_at: []const u8,
        default_branch: []const u8,
        // branches_url: [][]const u8
        // languages_url: [][]const u8
        // contributors_url: [][]const u8

        pub fn free(self: *@This(), alloc: std.mem.Allocator) void {
            alloc.free(self.full_name);
            alloc.free(self.description);
            alloc.free(self.html_url);
            alloc.free(self.language);
            alloc.free(self.license.name);
            alloc.free(self.created_at);
            alloc.free(self.updated_at);
            alloc.free(self.pushed_at);
            alloc.free(self.default_branch);
        }
    };

    var info = blk: {
        @setEvalBranchQuota(6000);
        var tokens = json.TokenStream.init(source);
        var info = try json.parse(Query, &tokens, .{
            .allocator = allocator,
            .ignore_unknown_fields = true,
        });
        errdefer info.free(allocator);
        break :blk info;
    };
    defer info.free(allocator);

    const color = TtyColor(@TypeOf(stdout)).init(stdout);
    {
        try color.setColor(.red);

        try stdout.print("  {s} ", .{info.full_name});
        if (info.fork) try stdout.writeAll("🔗 ");
        if (info.private) try stdout.writeAll("🔒 ");
        if (info.is_template) try stdout.writeAll("🗒; ");
        if (info.archived) try stdout.writeAll("📦 ");
        try stdout.writeByte('\n');

        try color.setColor(.reset);
    }
    {
        var x: usize = 0;
        while (x < info.description.len) {
            const end = blk: {
                if (x + 50 >= info.description.len) {
                    break :blk info.description.len - x;
                } else {
                    break :blk 50;
                }
            };

            const str = std.mem.trimLeft(u8, info.description[x .. x + end], " ");
            try stdout.print("{s}\n", .{str});
            x += end;
        }
        try stdout.writeByte('\n');
    }
    try stdout.print("- repository: {s}\n", .{info.html_url});
    try stdout.print("- license: {s}\n", .{info.license.name});
    try stdout.print("- default branch: {s}\n", .{info.default_branch});
    try stdout.print("- created: {s}\n", .{info.created_at[0..10]});
    // TODO: print in form "x hours ago" for below
    try stdout.print("- modified: {s} (last pushed: {s})\n", .{ info.updated_at[0..10], info.pushed_at[0..10] });
    try stdout.print("- language: {s}\n", .{info.language});
    try stdout.print("- size: {} KB\n", .{info.size});
    try stdout.print("- stars: {}\n", .{info.stargazers_count});
    try stdout.print("- watches: {}\n", .{info.watchers_count});
    try stdout.print("- forks: {}\n", .{info.forks_count});

    std.log.info("All your get requests are belong to us.", .{});
}
