#!/usr/bin/env python3
"""
Minimal DocReader server for testing connection
"""
import os
import sys
import logging
from concurrent import futures
import grpc
import uuid

# Add src directory to Python path
current_dir = os.path.dirname(os.path.abspath(__file__))
src_dir = os.path.join(current_dir, 'src')
if src_dir not in sys.path:
    sys.path.insert(0, src_dir)

try:
    from proto.docreader_pb2 import ReadResponse, Chunk
    from proto import docreader_pb2_grpc
except ImportError as e:
    print(f"Failed to import protobuf modules: {e}")
    print("Make sure protobuf files are generated. Run:")
    print("cd src && python -m grpc_tools.protoc --python_out=. --grpc_python_out=. --proto_path=. proto/docreader.proto")
    sys.exit(1)

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class MinimalDocReaderServicer(docreader_pb2_grpc.DocReaderServicer):
    """Minimal DocReader servicer for testing"""
    
    def ReadFromFile(self, request, context):
        """Handle file reading request"""
        try:
            request_id = getattr(request, 'request_id', '') or str(uuid.uuid4())
            file_name = request.file_name
            file_type = request.file_type or 'unknown'
            content_size = len(request.file_content)
            
            logger.info(f"[{request_id}] Received ReadFromFile request:")
            logger.info(f"  - File: {file_name}")
            logger.info(f"  - Type: {file_type}")
            logger.info(f"  - Size: {content_size} bytes")
            
            # Create a simple response with dummy content
            chunk = Chunk(
                content=f"This is a test response for file: {file_name}",
                metadata={"source": file_name, "type": file_type, "test": True}
            )
            
            response = ReadResponse(chunks=[chunk])
            logger.info(f"[{request_id}] Returning test response with 1 chunk")
            
            return response
            
        except Exception as e:
            logger.error(f"Error processing request: {e}")
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return ReadResponse(error=str(e))
    
    def ReadFromURL(self, request, context):
        """Handle URL reading request"""
        try:
            request_id = getattr(request, 'request_id', '') or str(uuid.uuid4())
            url = request.url
            
            logger.info(f"[{request_id}] Received ReadFromURL request for: {url}")
            
            # Create a simple response
            chunk = Chunk(
                content=f"This is a test response for URL: {url}",
                metadata={"source": url, "test": True}
            )
            
            response = ReadResponse(chunks=[chunk])
            logger.info(f"[{request_id}] Returning test response with 1 chunk")
            
            return response
            
        except Exception as e:
            logger.error(f"Error processing URL request: {e}")
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return ReadResponse(error=str(e))

def serve():
    """Start the gRPC server"""
    # Get port from environment variable or use default
    port = os.getenv('GRPC_PORT', '50051')
    
    # Create server with thread pool
    server = grpc.server(
        futures.ThreadPoolExecutor(max_workers=4),
        options=[
            ('grpc.max_send_message_length', 50 * 1024 * 1024),  # 50MB
            ('grpc.max_receive_message_length', 50 * 1024 * 1024),  # 50MB
        ]
    )
    
    # Add servicer to server
    docreader_pb2_grpc.add_DocReaderServicer_to_server(
        MinimalDocReaderServicer(), server
    )
    
    # Listen on port
    listen_addr = f'[::]:{port}'
    server.add_insecure_port(listen_addr)
    
    # Start server
    server.start()
    logger.info(f"DocReader server started on port {port}")
    logger.info("This is a minimal test server - file parsing is mocked")
    
    try:
        server.wait_for_termination()
    except KeyboardInterrupt:
        logger.info("Shutting down server...")
        server.stop(0)

if __name__ == '__main__':
    serve()