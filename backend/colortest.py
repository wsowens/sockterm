#!/usr/bin/env python
"""Simple server for testing how well a client supports colors via ANSI
escape codes.
"""
import asyncio
import itertools
import logging
import re
import traceback
import websockets

# even though swampymud is a package for creating MUDs, the color module
# is general purpose and respects ANSI standards for the SGR command
from swampymud.util import color as col

logging.basicConfig(level=logging.INFO)
HOSTNAME = 'localhost'
PORT = 8001


SGR_FUNCTIONS = {
    name.lower() : obj
    for name, obj in col.__dict__.items()
    if isinstance(obj, type) and issubclass(obj, col.SGRFunction) and
    obj not in [col.Color256, col.ColorRGB, col.SGRFunction]
}

def help_entry(classname):
    """return a help menu and the related escape code for a class"""
    lower = classname.lower()
    if lower in SGR_FUNCTIONS:
        Cls = SGR_FUNCTIONS[lower]
        demo = 'So warm with light his blended colors glow.'
        return (
            f"{Cls.__name__}\n"
            f"Escape Code: {'ESC + [ ' + Cls.sgr_param + 'm'}\n"
            f"Description: {Cls.__doc__}\n"
            f"Demo: {Cls(demo)}\n"
            f"Repr: {str(Cls(demo))!r}\n"
        )
    else:
        return f"No function with name '{classname}'\n"


FUNC_RE = re.compile(r"((\w+))\(")
TOKEN_RE = re.compile(r"((?:\w+)\()|((?<!\\)\))|(\s)")
def interpret(inp):
    """Interpret an expression with SGR functions"""
    stack = [""]

    for token in TOKEN_RE.split(inp):
        # token is empty string or None
        if not token:
            continue
        func_call = FUNC_RE.match(token)
        # maybe new function call
        if func_call:
            func_name = func_call.group(1).lower()
            if func_name in SGR_FUNCTIONS:
                # add current function to the stack,
                # then add empty content to grow
                stack.append(SGR_FUNCTIONS[func_name])
                stack.append("")
            else:
                return f"No SGR Function with name '{func_call.group(1)}'"
        # closing parenthesis, we need to pop off the stack
        elif token == ")":
            if len(stack) < 3:
                # TODO: add hint
                return f"Error. Unexpected close parenthesis."
            else:
                # get the content, the function, and apply it
                content = stack.pop()
                Func = stack.pop()
                stack[-1] += str(Func(content))
        # token is just text
        else:
            # fix any escaped parenthesis, add text to current content
            stack[-1] += token.replace("\\(", "(").replace("\\)", ")")
    if len(stack) != 1:
        return "Missing 1 or more close parentheses."
    return stack[0]

HELP_MENU = f"""The following functions are available:
{", ".join([Class.__name__ for Class in SGR_FUNCTIONS.values()])}

'help [Function]' for specific information on an SGR function, like so:

    help Underline

This help entry will also include a demo of the SGR function in action.
"""
def parse(msg):
    """Safely parse a provided message"""
    msg = msg.strip()
    args = msg.split()
    # 'help' command allows users to get help for different SGR params
    if args and args[0] == "help":
        class_names = args[1:]
        if not class_names:
            return HELP_MENU
        return "===\n".join(
            help_entry(name) for name in class_names
        )
    # 'test' command sends the SGR test
    elif args and args[0] == "test":
        return col.TEST_BASIC_SGR
    try:
        return interpret(msg) + "\n"
    except Exception as ex:
        logging.error(f"Critical error occurred interpreting input {msg!r}")
        logging.error(traceback.format_exc())
        return "Sorry, could not interpret input.\n"


def rainbow(inp: str) -> str:
    """Return a version of [inp] with rainbow colors"""
    output = ""
    color_classes = [col.Red, col.Green, col.Yellow,
                     col.Blue, col.Cyan, col.White]
    for letter, Color in zip(inp, itertools.cycle(color_classes)):
        output += Color(letter)
    return output


GREETING = f"""You are now connected to an {
    rainbow('interactive colortest')
}.
Type 'test' to examine which SGR parameters this terminal supports.

You can also try running your own custom commands, for example:

    Red(Underline(Hello, there!))

Type 'help' for more details.
"""


async def greet(websocket, path):
    """Welcome a new connection by sending the SGR test string, which
    contains most common formatting options supported by ANSI escape
    codes
    """
    logging.info("New websocket connecting: %r", websocket)
    # send the test string from the color module
    await websocket.send(GREETING)
    try:
        async for message in websocket:
            result = parse(message)
            await websocket.send(result)
    except websockets.exceptions.ConnectionClosedError:
        # websocket just disconnected, no big deal
        pass
    except Exception as ex:
        logging.error(traceback.format_exc())
        await websocket.send("Unexpected error, goodbye.\n")


async def main():
    """Start a websocket server and run it until completion"""
    logging.info("launching websocket server")
    server = await websockets.serve(greet, HOSTNAME, PORT)
    await server.wait_closed()

if __name__ == "__main__":
    asyncio.run(main())
