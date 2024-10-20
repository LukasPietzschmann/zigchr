# ZigCHR

For the [talk](https://github.com/LukasPietzschmann/zigtoberfest-talk) I gave at Zigtoberfest 2024, I coded up a CHR embedding for Zig using the
FreeCHR framework.

If you want to learn more about FreeCHR, go ahead and read [this
paper](https://doi.org/10.1007/978-3-031-45072-3_14). If you want to know more about
cool properties that CHR can bring to your algorithms, visit [my website for the
talk](https://lukas.pietzschmann.org/talks/zigtoberfest)

## Project Structure

- `src/`: Here you can find two example on how to use the embedding.
- `lib/`: The embedding itself.
- `utils/`: Some useful data structures and functions unrelated to CHR.

## How to build it

For each file inside the `src` directory, there exists a step. So lets say you want to
build and run the _min_ example. You can run `zig build min` to do so. For all examples
present in this repo, you can pass the query constraints though the commandline like the
following: `zig build min -- 1 3 5`.

If you add your own file in the `src` folder, the build system will automatically
generate a step for you.

### Additional flags

You can pass different flags to the build process to control how much logs the embedding
produces:

- `-Dlog` enabled logging. The embedding will print which rules were fired with which
  constraints, whats put into the store, ...
- `-Dnotag` wont print a constraints tag.
- `-Dmatchings` requires `-Dlog`. The embedding will print what combination of
  constraints are considered.
- `-Dstore` requires `-Dlog`. The embedding will print the constraint store when it's
  modified.
