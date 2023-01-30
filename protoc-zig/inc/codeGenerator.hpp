#ifndef CODEGENERATOR_HPP
#define CODEGENERATOR_HPP

#include "formatter.hpp"

#include <google/protobuf/compiler/code_generator.h>
#include <google/protobuf/descriptor.h>

#include <iostream>
#include <vector>
#include <memory>
#include <cstring>


/**
 * Implementation of protobuf code generator to output Zig code
 * https://developers.google.com/protocol-buffers/docs/reference/cpp/google.protobuf.compiler.code_generator
 */
namespace ZigProtobuf{

class ZigGenerator : public  google::protobuf::compiler::CodeGenerator
{

public:
    /**
     * Invoke the generator, gets called by google::protobuf::compiler::PluginMain
     */
    bool GenerateAll(const std::vector<const google::protobuf::FileDescriptor*>&, const std::string&,
                    google::protobuf::compiler::GeneratorContext*, std::string* ) const override;

    bool Generate(const google::protobuf::FileDescriptor*, const std::string&, 
                    google::protobuf::compiler::GeneratorContext*, std::string* ) const override;

private:
    /** Functions to handle parsing and generating code for the different parts of a protobuf message */
    void ProcessMessage(const google::protobuf::Descriptor*, Formatter&) const;
    void ProccessField(const google::protobuf::FieldDescriptor*, Formatter&, bool = false) const; 
    void ProcessEnum(const google::protobuf::EnumDescriptor*, Formatter&) const;
    void BuildDescriptorPool(const std::map<std::string, u_int>&, const std::vector<std::string>&, Formatter&) const;
    bool IsZigZagEncoded(const google::protobuf::FieldDescriptor*) const;
};

}

#endif
