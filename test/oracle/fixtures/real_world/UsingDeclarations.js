{
  using file = open("a.txt"), lock = acquire();
  read(file, lock);
}

async function copy(sources) {
  await using conn = await connect();
  for (using handle of handles(sources)) {
    write(conn, handle);
  }
  for (await using stream of streams) {
    drain(stream);
  }
}

switch (mode) {
  case "read": {
    using reader = open(mode);
    reader.run();
  }
}

// Where `using` is a variable name
using(x);
using[0] = 1;
for (using of list) {}
let y = using
in obj;
async function f() {
  await using(x);
  await using
  z = 1;
}
