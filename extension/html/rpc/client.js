const inhive = require("./inhive_grpc_web_pb.js");
const extension = require("./extension_grpc_web_pb.js");

const grpcServerAddress = '/';
const extensionClient = new extension.ExtensionHostServicePromiseClient(grpcServerAddress, null, null);
const inhiveClient = new inhive.CorePromiseClient(grpcServerAddress, null, null);

module.exports = { extensionClient ,inhiveClient};