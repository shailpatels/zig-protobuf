#include "codeGenerator.hpp"

namespace ZigProtobuf{

bool ZigGenerator::GenerateAll(const std::vector<const google::protobuf::FileDescriptor*>& files, const std::string& parameter,
                    google::protobuf::compiler::GeneratorContext* generator_context, std::string* error) const
{
    for(const auto& file : files){
        if(!Generate(file, parameter, generator_context, error)) {
            return false;
        }
    }

    Formatter::CopyProtobufInterfaceFiles(generator_context);
    return true;
}


bool ZigGenerator::Generate(const google::protobuf::FileDescriptor* file, const std::string&,
    google::protobuf::compiler::GeneratorContext* generator_context, std::string* error) const
{
    switch(file->syntax())
    {
        case google::protobuf::FileDescriptor::Syntax::SYNTAX_PROTO3:
            break;
        case google::protobuf::FileDescriptor::Syntax::SYNTAX_PROTO2:
            *error = "Proto 2 syntax is not supported";
            return false;
        case google::protobuf::FileDescriptor::Syntax::SYNTAX_UNKNOWN:
        default:	
            *error = "unknown syntax is not supported";
            return false;
    }

    Formatter formatter{file, generator_context};

    //create any imports
    for(int i = 0; i < file->dependency_count(); i++)
    {
        const std::string& source_name = Formatter::GetZigName(Formatter::StripProtoFromName(file->dependency(i)->name()));
        formatter.WriteLine({ "const ", source_name, " = @import(\"", Formatter::StripProtoFromName(file->dependency(i)->name()), "\");" });

        //add dependency's message and enum definitions to namespace
        for(int j = 0; j < file->dependency(i)->message_type_count(); j++){
            const std::string& message_name = Formatter::GetZigName(file->dependency(i)->message_type(j)->name());
            formatter.WriteLine({"pub const ", message_name, " = ", Formatter::GetZigName(source_name), ".", message_name, ";"});
        }

        for(int j = 0; j < file->dependency(i)->enum_type_count(); j++){
            const std::string& message_name = Formatter::GetZigName(file->dependency(i)->enum_type(j)->name());
            formatter.WriteLine({"pub const ", message_name, " = ", Formatter::GetZigName(source_name), ".", message_name, ";"});
        }
    }

    formatter.NewLine();
    
    //handle top level message and enum defs
    for(int i = 0; i < file->message_type_count(); i++){
        ProcessMessage(file->message_type(i), formatter);
        
        formatter.NewLine();
    }

    for(int i = 0; i < file->enum_type_count(); i++){
        ProcessEnum(file->enum_type(i), formatter);
    }

    return true;
}


/**
 * Convert protobuf message to zig struct type 
 */
void ZigGenerator::ProcessMessage(const google::protobuf::Descriptor* message, Formatter& formatter) const
{
    //create the struct definition
    formatter.WriteLine({"pub const ", Formatter::GetZigName(message->name()), " = struct{"}).PushIndent();
    std::map<std::string, u_int> field_names;   //map field names to their proto field number for a descriptor_pool
    std::vector<std::string> zig_zag_encoded;   //heh 'zig'

    //handle any nested messages
    for(int i = 0; i < message->nested_type_count(); i++){
        ProcessMessage(message->nested_type(i), formatter);
    }	

    for(int i = 0; i < message->enum_type_count(); i++){
        ProcessEnum(message->enum_type(i), formatter);
    }


    for(int i = 0; i < message->field_count(); i++)
    {
        const google::protobuf::FieldDescriptor* field = message->field(i);
        if(field->containing_oneof() == nullptr){
            ProccessField(field, formatter);
            formatter.NoIndent().Write({","}).NewLine().UseIndent();

            field_names.insert({ field->name(), field->number() });
            if(IsZigZagEncoded(field)){
                zig_zag_encoded.push_back(field->name());
            }
        }
    }


    for(int i = 0; i < message->real_oneof_decl_count(); i++)
    {
        //handle any oneofs as a union inside of this struct
        const google::protobuf::OneofDescriptor* oneof = message->oneof_decl(i);
        formatter.WriteLine({"pub const ", oneof->name(), " = union{" }).PushIndent();

        for(int j = 0; j < oneof->field_count(); j++)
        {
            ProccessField(oneof->field(j), formatter, true);
            if(j != oneof->field_count() - 1){
                formatter.NoIndent().Write({","});
            }

            formatter.UseIndent().NewLine();
        }

        formatter.PopIndent().WriteLine({"};"});
    }

    formatter.WriteLine({""});
    //insert helper functions
    formatter.WriteLine({"pub fn ParseFromString(string: []const u8, allocator: Allocator) DecodeError!", Formatter::GetZigName(message->name()), "{"})
        .PushIndent()
        .WriteLine({"return ProtobufMessage(", Formatter::GetZigName(message->name()), ").ParseFromString(string, allocator);"})
        .PopIndent().WriteLine({"}"});
    
    formatter.WriteLine({"pub fn SerializeToWriter(message: ", Formatter::GetZigName(message->name()), ", allocator: Allocator) []const u8 {"})
        .PushIndent()
        .WriteLine({"return ProtobufMessage(", Formatter::GetZigName(message->name()), ").SerializeToWriter(message, allocator);"})
        .PopIndent().WriteLine({"}"});

    //metadata for parsing wire format into this message
    BuildDescriptorPool(field_names, zig_zag_encoded, formatter);

    formatter.PopIndent().WriteLine({"};"});
}


/**
 * Add a new field to the struct we're building 
 */
void ZigGenerator::ProccessField(const google::protobuf::FieldDescriptor* field, Formatter& formatter, bool is_union) const 
{
    const std::string field_name = Formatter::GetZigName(field->name());
    const std::string is_repeated = field->is_repeated() ? "std.ArrayList(" : "";
    std::string default_type;

    switch(field->type())
    {
        using namespace google::protobuf;
        case FieldDescriptor::Type::TYPE_DOUBLE:
            formatter.Write({field_name, ": ", is_repeated, "f64"});
            default_type = "0";
            break;
        case FieldDescriptor::Type::TYPE_FLOAT:
            formatter.Write({field_name, ": ", is_repeated, "f32"});
            default_type = "0";
            break;
        case FieldDescriptor::Type::TYPE_INT64:
        case FieldDescriptor::Type::TYPE_SINT64:
        case FieldDescriptor::Type::TYPE_FIXED64:
        case FieldDescriptor::Type::TYPE_SFIXED64:
            formatter.Write({field_name, ": ", is_repeated, "i64"});
            default_type = "0";
            break;
        case FieldDescriptor::Type::TYPE_UINT64:
            formatter.Write({field_name, ": ", is_repeated, "u64"});
            default_type = "0";
            break;
        case FieldDescriptor::Type::TYPE_INT32:
        case FieldDescriptor::Type::TYPE_SINT32:
        case FieldDescriptor::Type::TYPE_FIXED32:
        case FieldDescriptor::Type::TYPE_SFIXED32:
            formatter.Write({field_name, ": ", is_repeated, "i32"});
            default_type = "0";
            break;
        case FieldDescriptor::Type::TYPE_BOOL:
            formatter.Write({field_name, ": ", is_repeated, "bool"});
            default_type = "false";
            break;
        case FieldDescriptor::Type::TYPE_BYTES:
            formatter.Write({field_name, ": ", is_repeated, "[]u8"});
            default_type = "\"\"";
            break;
        case FieldDescriptor::Type::TYPE_STRING:
            formatter.Write({field_name, ": ", is_repeated, "[]const u8"});
            default_type = "\"\"";
            break;
        case FieldDescriptor::Type::TYPE_UINT32:
            formatter.Write({field_name, ": ", is_repeated, "u32"});
            default_type = "0";
            break;
        case FieldDescriptor::Type::TYPE_ENUM:
            formatter.Write({field_name, ": ", is_repeated, field->enum_type()->name()});
            default_type = "@intToEnum(" + field->enum_type()->name() + ", 0)";
            break;
        case FieldDescriptor::Type::TYPE_MESSAGE:
            formatter.Write({field_name, ": ", is_repeated, field->message_type()->name()});
            default_type = field->message_type()->name() + "{}";
            break;
        default:
            std::cerr << "Received unknown field type (" << field->type() << ") on name = \"" + field->name() + "\"" << std::endl;
    }

    if(field->is_repeated()){
        formatter.NoIndent().Write({")"}).UseIndent();
        formatter.NoIndent().Write({" = undefined"});
    }else if(!is_union){
        formatter.NoIndent().Write({" = ", default_type, ""});
    }

    
}


/**
 * Convert protobuf enum to zig enum type 
 */
void ZigGenerator::ProcessEnum(const google::protobuf::EnumDescriptor* enum_type,  Formatter& formatter) const
{
    formatter.WriteLine({"pub const ", enum_type->name(), " = enum{"}).PushIndent();

    for(int i = 0; i < enum_type->value_count(); i++){
        formatter.Write({enum_type->value(i)->name()});

        if(i != enum_type->value_count() - 1){
            formatter.NoIndent().Write({","});
        }

        formatter.WriteLine({}).UseIndent();
    }

    formatter.PopIndent().WriteLine({"};"});
}


/**
 * Map the field names with their tag numbers so we can perform the lookup when decoding and assigning values
 */
void ZigGenerator::BuildDescriptorPool(const std::map<std::string, u_int>& field_names, const std::vector<std::string>& zig_zag_encoded, Formatter& formatter) const
{
    //if there are no values, do not create an empty enum set
    if(field_names.size() == 0)
        return;

    formatter.NewLine().Write({"pub const descriptor_pool = enum(u32){"});
    for(const auto& pair : field_names){
        formatter.NoIndent().Write({Formatter::GetZigName(pair.first), " = ", std::to_string(pair.second)}).Write({","});
    }

    formatter.Write({"};"}).NewLine().UseIndent().Write({"pub const zig_zag_encoded = enum{"});
    for(const auto& field : zig_zag_encoded){
        formatter.NoIndent().Write({Formatter::GetZigName(field)}).Write({","});
    }

    formatter.Write({"};"}).NewLine().UseIndent();
}


/**
 * returns if a field is ZigZag encoded (sint32,sint64 varints)
 */
bool ZigGenerator::IsZigZagEncoded(const google::protobuf::FieldDescriptor* field) const
{
    using namespace google::protobuf;
    return field->type() == FieldDescriptor::TYPE_SINT32 || field->type() == FieldDescriptor::TYPE_SINT64;
}

}
