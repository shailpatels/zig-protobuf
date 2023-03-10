#ifndef FORMATTER_HPP
#define FORMATTER_HPP

#include <string>

#include <google/protobuf/io/printer.h>
#include <google/protobuf/io/zero_copy_stream.h>
#include <google/protobuf/compiler/code_generator.h>
#include <google/protobuf/descriptor.h>

#define ZIGPB_VERSION "///zigpb version 0, google protobuf version "
#define AUTOGENERATED_NOTICE "///This file was automatically generated, do not edit!"

namespace ZigProtobuf{

/**
 * Formatter is class that owns the output stream per protobuf file getting processed
 */
class Formatter
{

public:
    Formatter(const google::protobuf::FileDescriptor*, google::protobuf::compiler::GeneratorContext*);

    /** Member functions, each one returns this formatter instance for function chaining */
    Formatter& Write(const std::initializer_list<std::string>&);
    Formatter& WriteLine(const std::initializer_list<std::string>&);
    Formatter& NewLine();
    Formatter& PushIndent(){ indent += std::string(Formatter::indent_size, ' '); return *this; };
    Formatter& PopIndent(){ indent.erase(0, Formatter::indent_size); return *this; };
    Formatter& NoIndent(){ use_indent = false; return *this; };
    Formatter& UseIndent() { use_indent = true; return *this; };

    /** Checks to see if a string is reserved by the zig language or by generated code - TODO incomplete */
    static std::string GetZigName(const std::string&);
    /** Remove the substring '.proto' from a string if it exists */
    static std::string StripProtoFromName(const std::string&);
    /** Copyover the contents of protobuf.zig.hpp to the genereated code area, this is created by prepare_env.py */
    static void CopyProtobufInterfaceFiles(google::protobuf::compiler::GeneratorContext*);

private:
    /** variable used for google protobuf printer utility class, currently unused */
    static constexpr char variable_delimiter = '$';
    /** how many spaces to use for indent */
    static constexpr int indent_size = 4;
    /** filename of the zig protobuf interface to be created */
    static constexpr std::string_view zig_protobuf_file{"protobuf.zig"};

    std::string indent{};
    bool use_indent = true;

    std::unique_ptr<google::protobuf::io::ZeroCopyOutputStream> io{nullptr};
    std::unique_ptr<google::protobuf::io::Printer> printer{nullptr};
};

}

#endif
