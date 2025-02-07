const std = @import("std");

// Create argument parser
const Config = struct {
    help: bool = false,
    verbose: bool = false,
    input_file: ?[]const u8 = null,
    output_file: ?[]const u8 = null,
    upper: bool = false,
};

fn parseArgument(config: *Config, allocator: std.mem.Allocator) !bool {
    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Parse arguments
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            config.help = true;
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            config.verbose = true;
        } else if (std.mem.eql(u8, arg, "--input") or std.mem.eql(u8, arg, "-i")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: Missing value for input file\n", .{});
                return error.InvalidArgument;
            }
            std.debug.print("{s}\n", .{args[i]});
            config.input_file = try allocator.dupe(u8, args[i]);
        } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: Missing value for output file\n", .{});
                return error.InvalidArgument;
            }
            config.output_file = try allocator.dupe(u8, args[i]);
        } else if (std.mem.eql(u8, arg, "--upper") or std.mem.eql(u8, arg, "-u")) {
            config.upper = true;
        } else {
            std.debug.print("Unknown argument: {s}\n", .{arg});
            printUsage();
            return error.InvalidArgument;
        }
    }

    return true;
}

fn printUsage() void {
    const usage =
        \\Usage: program [OPTIONS]
        \\
        \\Options:
        \\  -h, --help     Print this help message
        \\  -v, --verbose  Enable verbose output
        \\  -i, --input    Input file path
        \\  -o, --output   Output file path
        \\  -u, --upper    Use upper case hex letters. Default is lower case
        \\
    ;
    std.debug.print("{s}", .{usage});
}

fn printHexBytes(config: Config) !void {
    const file = try std.fs.cwd().openFile(config.input_file.?, .{});
    defer file.close();

    var buffer: [16]u8 = undefined;
    var offset: usize = 0;

    var buffered_reader = std.io.bufferedReader(file.reader());
    var reader = buffered_reader.reader();

    while (true) {
        const bytes_read = try reader.read(&buffer);
        if (bytes_read == 0) break;
        std.debug.print("{x:0>8}: ", .{offset});

        for (0..16) |i| {
            if (i < bytes_read) {
                if (config.upper) {
                    std.debug.print("{X:0>2}", .{buffer[i]});
                } else {
                    std.debug.print("{x:0>2}", .{buffer[i]});
                }
            } else {
                std.debug.print("  ", .{});
            }

            if (i % 2 != 0) {
                std.debug.print(" ", .{});
            }
        }

        // Print ASCII representation
        std.debug.print(" |", .{});
        for (0..bytes_read) |i| {
            // Print printable characters
            if (std.ascii.isPrint(buffer[i])) {
                std.debug.print("{c}", .{buffer[i]});
            } else {
                std.debug.print(".", .{});
            }
        }
        std.debug.print("|\n", .{});

        offset += bytes_read;
    }
}

pub fn main() !void {
    // Get allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var config: Config = .{};

    _ = try parseArgument(&config, allocator);
    // Handle --help
    if (config.help) {
        printUsage();
        return;
    }

    if (config.input_file) |input| {
        _ = try printHexBytes(config);
        allocator.free(input);
    }
    if (config.output_file) |output| {
        allocator.free(output);
    }
}
