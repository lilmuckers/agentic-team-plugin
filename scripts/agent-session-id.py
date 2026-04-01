#!/usr/bin/env python3
import argparse

parser = argparse.ArgumentParser(description='Generate canonical OpenClaw session ids for named agents.')
parser.add_argument('--project', required=True)
parser.add_argument('--agent', required=True)
parser.add_argument('--task')
args = parser.parse_args()

project = args.project.strip().lower().replace(' ', '-').replace('_', '-')
agent = args.agent.strip().lower()

if args.task:
    task = args.task.strip().lower().replace(' ', '-').replace('_', '-')
    print(f'{project}-{agent}-{task}')
else:
    print(f'{project}-{agent}')
