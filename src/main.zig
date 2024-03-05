const std = @import("std");
const ArgParser = @import("Argparser.zig");
const Arg = ArgParser.Arg;

const CODE_BISECT_ABORT = 255;
const CODE_BISECT_SKIP = 125;
const CODE_BISECT_GOOD = 0;
const CODE_BISECT_BAD = 1;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var stderr = std.io.getStdErr().writer();
    var stdout = std.io.getStdOut().writer();

    const arg_verbose = "verbose";
    const arg_inverse = "inverse";
    const arg_file = "file";
    const arg_string = "string";
    const parser = comptime ArgParser.Parser("Search a file for a string and set a return code for git bisect.", &[_]Arg{
        .{ .longName = arg_inverse, .shortName = 'i', .description = "Inverse the exit code so that a match indicates a bad/newer commit.", .argType = .bool, .default = "false", .isOptional = true },
        .{ .longName = arg_verbose, .description = "Print debug output when executed.", .argType = .bool, .default = "false", .isOptional = true },
        .{ .longName = arg_file, .shortName = 'f', .description = "Relative or absolute path of file to search in.", .argType = .string, .isOptional = false },
        .{ .longName = arg_string, .shortName = 's', .description = "String to search for in the given file.", .argType = .string, .isOptional = false },
    });

    var command_line_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, command_line_args);

    var args = parser.parse(allocator, command_line_args) catch |err| {
        switch (err) {
            ArgParser.ParseError.InvalidArgumentValue => {
                try stderr.print("ERROR: Invalid argument value\n", .{});
            },
            ArgParser.ParseError.MissingArgument => {
                try stderr.print("ERROR: Missing argument.\n", .{});
            },
            else => {},
        }
        try parser.printHelp(std.io.getStdErr());
        std.os.exit(CODE_BISECT_ABORT);
    };
    defer args.deinit();

    const bin_name = std.fs.path.basename(command_line_args[0]);
    const inverse = args.get(arg_inverse).?.value().bool;
    const verbose = args.get(arg_verbose).?.value().bool;
    const search_file_path = args.get(arg_file).?.value().string;
    const search_string = args.get(arg_string).?.value().string;

    if (verbose) {
        try stdout.print("{s}: Inverse match? {s}\n", .{ bin_name, if (inverse) "yes" else "no" });
        try stdout.print("{s}: Verbose output? {s}\n", .{ bin_name, if (verbose) "yes" else "no" });
        try stdout.print("{s}: Searched file is \"{s}\"\n", .{ bin_name, search_file_path });
        try stdout.print("{s}: Search string is \"{s}\"\n", .{ bin_name, search_string });
    }

    const abs_path = std.fs.cwd().realpathAlloc(allocator, search_file_path) catch {
        try stderr.print("{s}: unable to open file: {s}\n", .{ bin_name, search_file_path });
        std.os.exit(CODE_BISECT_SKIP);
    };
    defer allocator.free(abs_path);

    if (verbose) {
        try stdout.print("{s}: Opening file {s}\n", .{ bin_name, abs_path });
    }

    // std.debug.print("{s}\n", .{abs_path});
    var file = std.fs.cwd().openFile(search_file_path, .{}) catch {
        try stderr.print("{s}: unable to open file: {s}\n", .{ bin_name, abs_path });
        std.os.exit(CODE_BISECT_SKIP);
    };
    defer file.close();

    if (verbose) {
        try stdout.print("{s}: File handle is {any}\n", .{ bin_name, file.handle });
    }

    // const file_cont = try file.readToEndAlloc(allocator, std.math.maxInt(u64));
    // defer allocator.free(file_cont);

    var BuffReader = std.io.bufferedReader(file.reader());
    var fls = BuffReader.reader();

    var al = std.ArrayList(u8).init(allocator);
    defer al.deinit();

    while (true) {
        fls.streamUntilDelimiter(al.writer(), '\n', null) catch {
            break;
        };
        const line = try std.mem.concat(allocator, u8, &[_][]const u8{ al.items, "\n" });
        defer allocator.free(line);
        // std.debug.print("{s}", .{line});

        if (std.mem.indexOf(u8, line, search_string)) |idx| {
            if (idx > -1) {
                if (verbose) {
                    try stdout.print("{s}: Found search string!\n", .{bin_name});
                }

                if (inverse) {
                    if (verbose) {
                        try stdout.print("{s}: Exit code is {d}\n", .{ bin_name, CODE_BISECT_BAD });
                    }
                    std.os.exit(CODE_BISECT_BAD);
                } else {
                    if (verbose) {
                        try stdout.print("{s}: Exit code is {d}\n", .{ bin_name, CODE_BISECT_GOOD });
                    }
                    std.os.exit(CODE_BISECT_GOOD);
                }
            }
        }

        al.items.len = 0;
    }

    if (verbose) {
        try stdout.print("{s}: Search string not found in file.\n", .{bin_name});
    }
    if (inverse) {
        if (verbose) {
            try stdout.print("{s}: Exit code is {d}\n", .{ bin_name, CODE_BISECT_GOOD });
        }
        std.os.exit(CODE_BISECT_GOOD);
    } else {
        if (verbose) {
            try stdout.print("{s}: Exit code is {d}\n", .{ bin_name, CODE_BISECT_BAD });
        }
        std.os.exit(CODE_BISECT_BAD);
    }
}
