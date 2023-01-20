# Zig-Protobuf

## About

Zig-Protobuf is an implementation of [Google's Protocal Buffers (Protobuf)](https://protobuf.dev/). The project
is currently in development and incomplete. It has two parts, `protoc-zig`, a protoc plugin that parses `.proto` files
and generates zig code, and a Protobuf interface that is currently focused on serializing the protobuf wire format.

## Usage

You will need `protoc` installed, see the installation on the [protobuf GitHub Repo](https://github.com/protocolbuffers/protobuf#protocol-compiler-installation).

```
protoc --plugin=protoc-gen-zigpb=<path to zigpb> --zigpb_out=../generated --proto_path=<path to your proto files> <proto files to compile>
```

You can also place the `zigpb` under `/usr/bin` to avoid passing a path to the plugin each time

## Development

You will need the full `libprotobuf` installed, see [here](https://github.com/protocolbuffers/protobuf/blob/main/cmake/README.md#linux-builds)
*Note:* Make sure you use the same compiler you plan on using to build the `protoc-zig` code, for example, if you plan on using zig as your c++ compiler for `protoc-zig` you must also build `libprotobuf` with zig's c++ toolchain.
Once built, see `tools/prepare_env.py`, this will copy over the protobuf implementation into a header file for the plugin to generate when
parsing `.proto` files. Once done you can either use `cmake` or `zig build` to build the plugin.

### Zig Build

```
zig build
```

### Cmake

```
cd protoc-zig
mkdir build
cd build
CC="zig cc" CXX="zig c++" cmake ..
make
```

## Testing

The script `generate_zig_protobuf.py` will take the files in `test-protos` and generate the zig structs from them in `generated`
The script `generate_encoded.py` will generate some binary data to test decoding with, it takes an optional parameter to the path of `zigpb`, by
default it assumes you built with `cmake`

Once set up you can then run `zig test src/main.zig` or `zig test src/main.zig --test-filter <test-name>`


## Notes

- So far the zig file generation works only with the proto3 syntax currently and is probably incomplete and will most likely change
- Haven't done too much on encoding yet
- In the future would like to support additional features like converting to JSON, gRPC, and proto2 syntax
- Built with zig version 0.11.0-dev.823+cf85462a7

