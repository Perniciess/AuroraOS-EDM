# SPDX-FileCopyrightText: 2024 Open Mobile Platform LLC <community@omp.ru>
# SPDX-License-Identifier: BSD-3-Clause

import asyncio
from websocket.websocket import Websocket


async def main():
    server = Websocket(ssl_cert="localhost.pem")
    try:
        await server.start_server()
    except KeyboardInterrupt:
        print("\nПолучен сигнал на остановку сервера...")
        await server.stop_server()


if __name__ == "__main__":
    asyncio.run(main())
