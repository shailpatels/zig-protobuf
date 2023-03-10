import os
import glob

'''
clean up autogenerated files
'''

tgts = [
    "generated",
    "protoc-zig/inc/protobuf.zig.hpp"
]

def clean():
    base_path = "../"
    for tgt in tgts:
        if os.path.isdir(base_path + tgt):
            print("removing ", base_path + tgt + "/*")
            for file in glob.glob(base_path + tgt + "/*"):
                os.remove(file)

        elif os.path.isfile(base_path + tgt):
            print("removing ", base_path + tgt)
            os.unlink(base_path + tgt)

if __name__ == "__main__":
    clean()
