use crate::options::JobStartOptions;
use portable_pty::{native_pty_system, CommandBuilder, PtySize, PtySystem};
use std::sync::atomic::AtomicUsize;

struct Job {
    id: usize,
    pid: Option<u32>,

    pty: Option<std::process::Child>,
    stdin: Option<std::process::ChildStdin>,
    stdout: Option<std::process::ChildStdout>,
    stderr: Option<std::process::ChildStderr>,

    options: JobStartOptions,
}

impl Job {
    fn new(id: usize, cmd: &Vec<String>, options: JobStartOptions) -> Self {}
}
