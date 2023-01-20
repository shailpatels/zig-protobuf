import subprocess
import sys


'''
Run the zigpb protoc plugin with the files under test-protos to test against
Usage: python3 generate_encoded [path to zigpb binary]
'''


def build_files(bin_loc : str):
    command = f"protoc --plugin=protoc-gen-zigpb={bin_loc} --zigpb_out=../generated --proto_path=../test-protos/ ../test-protos/*.proto"
    print(command)
    result = subprocess.check_output([command], shell=True)

    if(len(result) > 0):
        print(result)


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) == 0:
        bin_loc = "../protoc-zig/build/zigpb"
    else:
        bin_loc = args[0]

    build_files(bin_loc)
