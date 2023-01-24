import subprocess


'''
Generate some test data by taking the test-protos files and encoding them in the protobuf wire format with some precanned data
and save the result to a file that can be read in for testing
'''

generated_path = "../generated/"


def concat_data(arr):
    result = ""
    for x in arr:
        result += x + "\n"

    return result


def write_encoded_data():
    for test_case in test_cases:
        data = concat_data(test_case["data"])

        process = subprocess.Popen(("echo", data), stdout=subprocess.PIPE)
        command = f"protoc --encode {test_case['message_name']} --proto_path='../test-protos/' {test_case['file']}"
        print(command)
        
        output = subprocess.check_output((command), stdin=process.stdout, shell=True)
        process.wait()

        with open(generated_path + test_case["output_name"], "wb") as f:
            f.write(output)


test_cases = [
    {
        "message_name" : "Test1",
        "file" : "simple.proto",
        "output_name" : "simple.Test1.1.bin",
        "data" : ["a:150"]
    },
    {
        "message_name" : "BasicRepeated",
        "file" : "simple.proto",
        "output_name" : "simple.BasicRepeated.1.bin",
        "data" : [
            "a:false",
            "a:true",
            "b:25",
            "c:3.14",
            "c:3.20"
        ]
    },
    {
        "message_name" : "RepeatedStrings",
        "file" : "simple.proto",
        "output_name" : "simple.RepeatedStrings.1.bin",
        "data" : [
            "a:\"first\"",
            "a:\"second\"",
            "b:25"
        ]
    },
    {
        "message_name" : "NestedMessage",
        "file" : "simple.proto",
        "output_name" : "simple.NestedMessage.1.bin",
        "data" : [
            "a:{b:\"hello\"}"
        ]
    },
    {
        "message_name" : "BasicMap",
        "file" : "simple.proto",
        "output_name" : "simple.BasicMap.1.bin",
        "data" : [
            "map_field:{key:\"A\", value:1}"  
            "map_field:{key:\"B\", value:2}"  
            "map_field:{key:\"C\", value:3}"  
        ]
    },
    {
        "message_name" : "test.SearchRequest",
        "file" : "message.proto",
        "output_name" : "message.SearchRequest.1.bin",
        "data" : [
            "query:\"testing\"",
            "page_number:5",
            "result_per_page:10"
        ]
    },
    {
        "message_name" : "Foo",
        "file" : "test.proto",
        "output_name" : "test.Foo.1.bin",
        "data" : [
            "a:100",
            "b:3.14",
            "c:-23",
            "d:10000000000000",
            "e: 5",
            "e: 4",
            "e: 2",
            "e: 1",
            "f: 150",
            "g: -20",
            "h: 200",
            "i: 900",
            "j: 23",
            "k: 55",
            "l: 1",
            "m: 0",
            "n: 19",
            "o: true",
            "p: \"test1\""
            "p: \"test2\""
        ]
    }
]


if __name__ == "__main__":
    write_encoded_data()
