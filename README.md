# n150 componentized ops

## Interface

- `./run <command> [options]`

## System Commands

- `init` - Initialize system infrastructure
- `cleanup` - Remove system infrastructure  
- `tree` - Show directory tree

## Components

- `net`

## Component Verbs

- `install`, `uninstall`, `start`, `stop`, `help`

## Output policy

- Only `help` prints descriptive usage text.
- All other commands are quiet-by-default; errors go to stderr and return non-zero.
