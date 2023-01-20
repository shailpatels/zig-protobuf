import os.path
import shutil

'''
Set up developer area, run from tools dir
'''


#sym link the generated dir inside of src to use for testing
if not (os.path.islink('../src/generated')):
    src = '../generated'
    dest = '../src/generated'

    os.symlink(src, dest)
    print(f'symlinking {src} -> {dest}')


#copy protobuf encoding/decoding files to c++ generator
src = '../src/protobuf.zig'
dest = '../protoc-zig/inc/protobuf.zig.hpp'
print(f'copying {src} -> {dest}')


with open(src, "r") as f:
    with open(dest, "w") as tgt:

        tgt.write("#ifndef PROTOBUF_ZIG_HPP\n")
        tgt.write("#define PROTOBUF_ZIG_HPP\n\n")
        tgt.write("#include <string>\n\n")

        tgt.write("static constexpr std::string_view zig_encoding_interface = R\"(")

        for data in f:
            tgt.write(data)

        tgt.write(")\";\n")
        tgt.write("#endif")
