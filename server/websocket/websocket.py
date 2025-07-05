# SPDX-FileCopyrightText: 2024 Open Mobile Platform LLC <community@omp.ru>
# SPDX-License-Identifier: BSD-3-Clause

import asyncio
import binascii
import json
import os
from datetime import datetime
from pathlib import Path

import ssl

import websockets
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.x509 import load_pem_x509_certificate
from database.database import Database
from dotenv import load_dotenv


class Websocket:
    def __init__(self, host="0.0.0.0", port=8765, ssl_cert=None):
        self.host = host
        self.port = port
        self.ssl_cert = ssl_cert
        self.env_init()
        self.files_folder()

    def env_init(self):
        dotenv_path = os.path.join(os.path.dirname(__file__), "..", ".env")
        load_dotenv(dotenv_path)
        password = os.getenv("SERVER_PASSWORD")
        if password is None:
            raise ValueError(
                "Переменная окружения SERVER_PASSWORD_HASH не найдена. Проверьте файл .env."
            )
        self.password = password

    def files_folder(self):
        self.upload_dir = Path("uploads")
        self.upload_dir.mkdir(exist_ok=True)

    async def start_server(self):
        if self.ssl_cert:
            ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ssl_context.load_cert_chain(certfile=self.ssl_cert)
        else:
            ssl_context = None

        self.upload_dir.mkdir(exist_ok=True)
        self.server = await websockets.serve(
            self.handle_connection,
            self.host,
            self.port,
            ssl=ssl_context
        )

        print("Сервер запущен")
        await asyncio.Future()

    async def stop_server(self):
        self.server.close()
        await self.server.wait_closed()
        print("Сервер остановлен")

    async def handle_connection(self, websocket):
        print("Новое подключение:", websocket.remote_address)
        try:
            password_msg = await websocket.recv()
            if password_msg == self.password:
                await websocket.send("Успешная авторизация")

                while True:
                    message = await websocket.recv()
                    print("Получено сообщение:", message)

                    if message == "GET_FILES_LIST":
                        await self.send_files_list(websocket)
                    elif message.startswith("FILENAME:"):
                        original_filename = message.split(":", 1)[1]
                        current_time = datetime.now().strftime("%d-%m-%Y_%H%M%S")

                        pdf_data = await self.receive_file(websocket, "PDF")
                        pdf_filename = f"{original_filename}_{current_time}.pdf"
                        pdf_path = self.upload_dir / pdf_filename
                        pdf_path.write_bytes(pdf_data)
                        print(f"PDF сохранён как {pdf_filename}")

                        hash_data = await self.receive_file(websocket, "HASH")
                        hash_filename = f"{original_filename}_{current_time}.sig"
                        hash_path = self.upload_dir / hash_filename
                        hash_path.write_bytes(hash_data)
                        print(f"Hash сохранён как {hash_filename}")

                        cert_data = await self.receive_file(websocket, "CERT")
                        cert_filename = f"{original_filename}_{current_time}.pem"
                        cert_path = self.upload_dir / cert_filename
                        cert_path.write_bytes(cert_data)
                        print(f"Certificate сохранён как {cert_filename}")

                        if await self.verify_pdf_signature(
                            pdf_path, cert_path, hash_path
                        ):
                            db = Database()
                            db.save_file(
                                fileName=original_filename,
                                fileStatus="signed",
                                filePath=pdf_path,
                                certPath=cert_path,
                                fileHash=self.hash,
                            )

                            await websocket.send("FILE_SAVED_SUCCESS")
                            print("Успешно сохранено")
                        else:
                            await websocket.send("FILE_SAVED_ERROR")
                            print("Ошибка сохранения")
                    elif message.startswith("GET FILE:"):
                        id_str = message.split(":", 1)[1].strip()
                        try:
                            file_id = int(id_str)
                            db = Database()
                            file_info = db.get_file_by_id(file_id)

                            if file_info is None:
                                await websocket.send("FILE_NOT_FOUND")
                            else:
                                file_path = Path(file_info["file_path"])
                                if file_path.exists():
                                    await websocket.send(f"FILE_NAME:{file_path.name}")
                                    await self.send_file(websocket, file_path)
                                else:
                                    await websocket.send("FILE_NOT_FOUND")
                        except ValueError:
                            await websocket.send("INVALID_FILE_ID")

                    else:
                        websocket.close()
        except websockets.exceptions.ConnectionClosedOK:
            print("Клиент отключился")
        except Exception as e:
            print(f"Ошибка: {e}")
        finally:
            await websocket.close()

    async def receive_file(self, websocket, file_type):
        file_data = b""
        while True:
            msg = await websocket.recv()
            if isinstance(msg, str) and msg == f"EOF_{file_type}":
                break
            if isinstance(msg, bytes):
                file_data += msg

        return file_data

    async def verify_pdf_signature(self, pdf_path, pem_cert_path, sig_path):
        with open(pdf_path, "rb") as f:
            pdf_data = f.read()

        with open(pem_cert_path, "rb") as f:
            cert = load_pem_x509_certificate(f.read(), default_backend())
            pubkey = cert.public_key()

        with open(sig_path, "rb") as f:
            signature = f.read()

        decrypted_hash = pubkey.recover_data_from_signature(
            signature, padding.PKCS1v15(), hashes.SHA256()
        )

        hasher = hashes.Hash(hashes.SHA256(), default_backend())
        hasher.update(pdf_data)
        pdf_hash = hasher.finalize()
        pdf_hash_hex = binascii.hexlify(pdf_hash).decode()

        decrypted_hash_hex = binascii.hexlify(decrypted_hash).decode()

        if decrypted_hash_hex == pdf_hash_hex:
            self.hash = decrypted_hash.hex()
            return True

        return False

    async def send_files_list(self, websocket):
        db = Database()
        await websocket.send(
            "FILE_LIST:" + json.dumps(db.get_files_list(), ensure_ascii=False)
        )

    async def send_file(self, websocket, file_path: Path):
        with open(file_path, "rb") as f:
            while chunk := f.read(4096):
                await websocket.send(chunk)
        await websocket.send("EOF_FILE")
