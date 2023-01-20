#include <google/protobuf/compiler/plugin.h>

#include "codeGenerator.hpp"

int main(int argc, char ** argv){
    GOOGLE_PROTOBUF_VERIFY_VERSION;

    ZigProtobuf::ZigGenerator generator{};
    return google::protobuf::compiler::PluginMain(argc, argv, &generator);
}
