import asyncio
import logging
import re
import tempfile
import os
import subprocess
import shutil
from io import BytesIO
from typing import Optional, List, Tuple
# import textract  # 替换为更稳定的解决方案
import magic
from PIL import Image
import zipfile
import xml.etree.ElementTree as ET

from .base_parser import BaseParser
from .docx_parser import DocxParser, Docx

logger = logging.getLogger(__name__)


class DocParser(BaseParser):
    """DOC document parser"""

    def parse_into_text(self, content: bytes) -> str:
        """Parse DOC document

        Args:
            content: DOC document content

        Returns:
            Parse result
        """
        logger.info(f"Parsing DOC document, content size: {len(content)} bytes")

        # Save byte content as a temporary file
        with tempfile.NamedTemporaryFile(suffix=".doc", delete=False) as temp_file:
            temp_file_path = temp_file.name
            temp_file.write(content)
            temp_file.flush()
            logger.info(f"Saved DOC content to temporary file: {temp_file_path}")

        try:
            # First try to convert to docx format to extract images
            if self.enable_multimodal:
                logger.info("Multimodal enabled, attempting to extract images from DOC")
                docx_content = self._convert_doc_to_docx(temp_file_path)

                if docx_content:
                    logger.info("Successfully converted DOC to DOCX, using DocxParser")
                    # Use existing DocxParser to parse the converted docx
                    docx_parser = DocxParser(
                        file_name=self.file_name,
                        file_type="docx",
                        enable_multimodal=self.enable_multimodal,
                        chunk_size=self.chunk_size,
                        chunk_overlap=self.chunk_overlap,
                        chunking_config=self.chunking_config,
                        separators=self.separators,
                    )
                    text = docx_parser.parse_into_text(docx_content)
                    logger.info(f"Extracted {len(text)} characters using DocxParser")

                    # Clean up temporary file
                    os.unlink(temp_file_path)
                    logger.info(f"Deleted temporary file: {temp_file_path}")

                    return text
                else:
                    logger.warning(
                        "Failed to convert DOC to DOCX, falling back to text-only extraction"
                    )

            # If image extraction is not needed or conversion failed, try using antiword to extract text
            try:
                logger.info("Attempting to parse DOC file with antiword")
                # Check if antiword is installed
                antiword_path = self._find_antiword_path()

                if antiword_path:
                    # Use antiword to extract text directly
                    logger.info(f"Using antiword at {antiword_path} to extract text")
                    process = subprocess.Popen(
                        [antiword_path, temp_file_path],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                    )
                    stdout, stderr = process.communicate()

                    if process.returncode == 0:
                        text = stdout.decode("utf-8", errors="ignore")
                        logger.info(
                            f"Successfully extracted {len(text)} characters using antiword"
                        )

                        # Clean up temporary file
                        os.unlink(temp_file_path)
                        logger.info(f"Deleted temporary file: {temp_file_path}")

                        return text
                    else:
                        logger.warning(
                            f"antiword extraction failed: {stderr.decode('utf-8', errors='ignore')}"
                        )
                else:
                    logger.warning("antiword not found, falling back to alternative methods")
            except Exception as e:
                logger.warning(
                    f"Error using antiword: {str(e)}, falling back to alternative methods"
                )

            # 如果antiword失败，尝试使用替代方案
            logger.info("尝试使用替代方案解析DOC文件")
            text = self._extract_text_fallback(temp_file_path)
            if text:
                logger.info(
                    f"使用替代方案成功提取{len(text)}个字符"
                )
            else:
                logger.error("所有解析方法都失败了")
                text = ""

            # Clean up temporary file
            os.unlink(temp_file_path)
            logger.info(f"Deleted temporary file: {temp_file_path}")

            return text
        except Exception as e:
            logger.error(f"Error parsing DOC document: {str(e)}")
            # Ensure temporary file is cleaned up
            if os.path.exists(temp_file_path):
                os.unlink(temp_file_path)
                logger.info(f"Deleted temporary file after error: {temp_file_path}")
            return ""

    def _convert_doc_to_docx(self, doc_path: str) -> Optional[bytes]:
        """Convert DOC file to DOCX format

        Uses LibreOffice/OpenOffice for conversion

        Args:
            doc_path: DOC file path

        Returns:
            Byte stream of DOCX file content, or None if conversion fails
        """
        logger.info(f"Converting DOC to DOCX: {doc_path}")

        # Create a temporary directory to store the converted file
        temp_dir = tempfile.mkdtemp()
        docx_path = os.path.join(temp_dir, "converted.docx")

        try:
            # Check if LibreOffice or OpenOffice is installed
            soffice_path = self._find_soffice_path()
            if not soffice_path:
                logger.error(
                    "LibreOffice/OpenOffice not found, cannot convert DOC to DOCX"
                )
                return None

            # Execute conversion command
            logger.info(f"Using {soffice_path} to convert DOC to DOCX")
            cmd = [
                soffice_path,
                "--headless",
                "--convert-to",
                "docx",
                "--outdir",
                temp_dir,
                doc_path,
            ]

            logger.info(f"Running command: {' '.join(cmd)}")
            process = subprocess.Popen(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )
            stdout, stderr = process.communicate()

            if process.returncode != 0:
                logger.error(
                    f"Error converting DOC to DOCX: {stderr.decode('utf-8', errors='ignore')}"
                )
                return None

            # Find the converted file
            for file in os.listdir(temp_dir):
                if file.endswith(".docx"):
                    converted_file = os.path.join(temp_dir, file)
                    logger.info(f"Found converted file: {converted_file}")

                    # Read the converted file content
                    with open(converted_file, "rb") as f:
                        docx_content = f.read()

                    logger.info(
                        f"Successfully read converted DOCX file, size: {len(docx_content)} bytes"
                    )
                    return docx_content

            logger.error("No DOCX file found after conversion")
            return None

        except Exception as e:
            logger.error(f"Error during DOC to DOCX conversion: {str(e)}")
            return None
        finally:
            # Clean up temporary directory
            try:
                shutil.rmtree(temp_dir)
                logger.info(f"Cleaned up temporary directory: {temp_dir}")
            except Exception as e:
                logger.warning(f"Failed to clean up temporary directory: {str(e)}")

    def _find_soffice_path(self) -> Optional[str]:
        """Find LibreOffice/OpenOffice executable path

        Returns:
            Executable path, or None if not found
        """
        # Common LibreOffice/OpenOffice executable paths
        possible_paths = [
            # Linux
            "/usr/bin/soffice",
            "/usr/lib/libreoffice/program/soffice",
            "/opt/libreoffice25.2/program/soffice",
            # macOS
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
            # Windows
            "C:\\Program Files\\LibreOffice\\program\\soffice.exe",
            "C:\\Program Files (x86)\\LibreOffice\\program\\soffice.exe",
        ]

        # Check if path is set in environment variable
        libreoffice_path = os.environ.get("LIBREOFFICE_PATH")
        if libreoffice_path:
            possible_paths.insert(0, libreoffice_path)

        for path in possible_paths:
            if os.path.exists(path):
                logger.info(f"Found LibreOffice/OpenOffice at: {path}")
                return path

        # Try to find in PATH
        try:
            result = subprocess.run(
                ["which", "soffice"], capture_output=True, text=True
            )
            if result.returncode == 0 and result.stdout.strip():
                path = result.stdout.strip()
                logger.info(f"Found LibreOffice/OpenOffice in PATH: {path}")
                return path
        except Exception:
            pass

        logger.warning("LibreOffice/OpenOffice not found")
        return None

    def _find_antiword_path(self) -> Optional[str]:
        """Find antiword executable path

        Returns:
            Executable path, or None if not found
        """
        # Common antiword executable paths
        possible_paths = [
            # Linux/macOS
            "/usr/bin/antiword",
            "/usr/local/bin/antiword",
            # Windows
            "C:\\Program Files\\Antiword\\antiword.exe",
            "C:\\Program Files (x86)\\Antiword\\antiword.exe",
        ]

        # Check if path is set in environment variable
        antiword_path = os.environ.get("ANTIWORD_PATH")
        if antiword_path:
            possible_paths.insert(0, antiword_path)

        for path in possible_paths:
            if os.path.exists(path):
                logger.info(f"Found antiword at: {path}")
                return path

        # Try to find in PATH
        try:
            result = subprocess.run(
                ["which", "antiword"], capture_output=True, text=True
            )
            if result.returncode == 0 and result.stdout.strip():
                path = result.stdout.strip()
                logger.info(f"Found antiword in PATH: {path}")
                return path
        except Exception:
            pass

        logger.warning("antiword not found")
        return None

    def _extract_text_fallback(self, doc_path: str) -> str:
        """使用备用方案提取DOC文件文本
        
        Args:
            doc_path: DOC文件路径
            
        Returns:
            提取的文本内容
        """
        try:
            # 尝试使用python-docx的替代方案
            logger.info("尝试使用docx2txt处理DOC文件")
            try:
                import docx2txt
                # 先尝试直接使用docx2txt（可能对某些DOC文件有效）
                text = docx2txt.process(doc_path)
                if text and text.strip():
                    logger.info(f"docx2txt成功提取{len(text)}个字符")
                    return text
            except ImportError:
                logger.warning("docx2txt不可用")
            except Exception as e:
                logger.warning(f"docx2txt处理失败: {str(e)}")
            
            # 尝试使用catdoc（另一个替代工具）
            try:
                logger.info("尝试使用catdoc提取文本")
                result = subprocess.run(
                    ["catdoc", doc_path], 
                    capture_output=True, 
                    text=True, 
                    timeout=30
                )
                if result.returncode == 0 and result.stdout.strip():
                    text = result.stdout
                    logger.info(f"catdoc成功提取{len(text)}个字符")
                    return text
            except (subprocess.TimeoutExpired, FileNotFoundError, Exception) as e:
                logger.warning(f"catdoc处理失败: {str(e)}")
            
            # 最后的备用方案：使用简单的二进制文本提取
            logger.info("使用简单的二进制文本提取作为最后备用")
            with open(doc_path, 'rb') as f:
                content = f.read()
                
            # 尝试从二进制内容中提取可读文本
            try:
                # DOC文件中的文本通常以UTF-16或其他编码存储
                import re
                # 提取可打印字符，过滤控制字符
                text_bytes = re.findall(rb'[\x20-\x7E\xA0-\xFF]{4,}', content)
                text_parts = []
                
                for part in text_bytes:
                    try:
                        # 尝试不同的编码
                        for encoding in ['utf-8', 'utf-16', 'cp1252', 'iso-8859-1']:
                            try:
                                decoded = part.decode(encoding, errors='ignore')
                                if len(decoded.strip()) > 3:  # 只保留有意义的文本
                                    text_parts.append(decoded)
                                break
                            except UnicodeDecodeError:
                                continue
                    except Exception:
                        continue
                
                if text_parts:
                    text = ' '.join(text_parts)
                    # 清理文本
                    text = re.sub(r'\s+', ' ', text)  # 合并多个空白字符
                    text = text.strip()
                    
                    if len(text) > 50:  # 只有当提取到足够的文本时才返回
                        logger.info(f"使用二进制提取方法成功提取{len(text)}个字符")
                        return text
                        
            except Exception as e:
                logger.warning(f"二进制文本提取失败: {str(e)}")
            
            logger.error("所有备用方案都失败了")
            return ""
            
        except Exception as e:
            logger.error(f"备用文本提取失败: {str(e)}")
            return ""


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    logger.info("Running DocParser in standalone mode")

    file_name = "/path/to/your/test.doc"
    logger.info(f"Processing file: {file_name}")

    doc_parser = DocParser(
        file_name, enable_multimodal=True, chunk_size=512, chunk_overlap=60
    )
    logger.info("Parser initialized, starting processing")

    with open(file_name, "rb") as f:
        content = f.read()

    text = doc_parser.parse_into_text(content)
    logger.info(f"Processing complete, extracted text length: {len(text)}")
    logger.info(f"Sample text: {text[:200]}...")
