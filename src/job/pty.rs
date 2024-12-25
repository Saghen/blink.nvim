use crate::options::JobStartOptions;
use anyhow::Result;
use portable_pty::{Child, CommandBuilder, PtyPair, PtySize, native_pty_system};

struct JobPty {
    id: usize,

    pid: Option<u32>,
    child: Box<dyn Child>,
    pair: PtyPair,
    stdin: Box<dyn std::io::Write>,
    stdout: Box<dyn std::io::Read>,

    options: JobStartOptions,
}

impl JobPty {
    fn new(id: usize, cmd: &Vec<String>, options: JobStartOptions) -> Result<Self> {
        // Use the native pty implementation for the system
        let pty_system = native_pty_system();

        // Create a new pty
        let pair = pty_system.openpty(PtySize {
            rows: options.height.unwrap_or(24) as u16,
            cols: options.width.unwrap_or(80) as u16,
            // Not all systems support pixel_width, pixel_height,
            // but it is good practice to set it to something
            // that matches the size of the selected font.  That
            // is more complex than can be shown here in this
            // brief example though!
            pixel_width: 0,
            pixel_height: 0,
        })?;

        // Build the command
        let mut cmd = CommandBuilder::from_argv(cmd.iter().map(|s| s.into()).collect());
        cmd.cwd(&options.cwd);

        if options.clear_env {
            cmd.env_clear();
        }
        for (key, value) in options.env.iter() {
            cmd.env(key, value);
        }

        let child = pair.slave.spawn_command(cmd)?;
        let pid = child.process_id();

        let stdin = pair.master.take_writer()?;
        let stdout = pair.master.try_clone_reader()?;

        Ok(JobPty {
            id,
            pid,
            child,
            pair,
            stdin,
            stdout,
            options,
        })
    }

    fn send(&mut self, data: &[u8]) -> Result<()> {
        self.stdin.write_all(data)?;
        Ok(())
    }

    fn pid(&self) -> u32 {
        self.pid.unwrap()
    }

    fn stop(&mut self) {
        // TODO: send SIGTERM, and then SIGKILL after timeout
        self.child.kill().unwrap();
    }

    fn poll(&mut self) -> Result<bool> {
        self.poll_stdout()?;
        self.poll_exit()
    }

    fn poll_stdout(&mut self) -> Result<bool> {
        if let Some(on_stdout) = &self.options.on_stdout {
            if self.options.stdout_buffered {
                let mut buf = vec![];
                self.stdout.read_to_end(&mut buf)?;
                on_stdout.call::<()>(buf).unwrap();
            }

            let mut buf = [0; 2048];
            while let Ok(bytes_read) = self.stdout.read(&mut buf) {
                if bytes_read > 0 {
                    on_stdout.call::<()>(&buf[..bytes_read]).unwrap();
                }
                return Ok(true);
            }
        }
        Ok(false)
    }

    fn poll_exit(&mut self) -> Result<bool> {
        let status = self.child.try_wait()?;
        if let Some(status) = &status {
            if let Some(on_exit) = &self.options.on_exit {
                on_exit.call::<()>(status.exit_code()).unwrap();
            }
        }
        return Ok(status.is_some());
    }
}
