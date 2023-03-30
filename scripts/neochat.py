import argparse
import json
import sys

import openai


# Define the function that is called when the 'chat' subcommand is specified
def chat_completions():
    kwargs = json.load(sys.stdin)

    rsp = openai.ChatCompletion.create(
        **kwargs,
    )
    if kwargs.get("stream", True):
        for chunk in rsp:
            assert isinstance(chunk, dict)
            content = chunk.get("choices", [{}])[0].get("delta", {}).get("content")
            if content is not None:
                print(content, end="", flush=True)
    else:
        assert isinstance(rsp, dict)
        print(rsp.get("choices", [{}])[0].get("message", {}).get("content", ""))


def main():
    # Create the argument parser
    parser = argparse.ArgumentParser(description="neochat")

    subparsers = parser.add_subparsers()
    # Create a subparser for the chat command
    # and set its default function to 'chat_completions'
    chat_parser = subparsers.add_parser("chat", help="chat completions")
    chat_parser.set_defaults(func=chat_completions)

    # Parse the user input and call the corresponding function
    args = parser.parse_args()
    args.func()


if __name__ == "__main__":
    main()
