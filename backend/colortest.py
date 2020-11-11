#!/usr/bin/env python
"""Simple server for testing how well a client supports colors via ANSI
escape codes.
"""
import asyncio
import websockets

# even though swampymud is a package for creating MUDs, the color module
# is general purpose and respects ANSI standards for the SGR command
from swampymud.util import color

HOSTNAME = 'localhost'
PORT = 8001

async def greet(websocket, path):
    """Welcome a new connection by sending the SGR test string, which
    contains most common formatting options supported by ANSI escape
    codes
    """
    # send the test string from the color module
    await websocket.send(color.TEST_BASIC_SGR)
    try:
        async for message in websocket:
            # TODO: allow for interactive testing
            pass
    finally:
        pass

async def main():
    """Start a websocket server and run it until completion"""
    print("launching websocket server")
    server = await websockets.serve(greet, HOSTNAME, PORT)
    await server.wait_closed()

if __name__ == "__main__":
    asyncio.run(main())
